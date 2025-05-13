#! /usr/bin/bash
source utils.sh
source table_helpers.sh
source regexp.sh

# parameter 1: database name
list_tables () {
  local database_name="$1"

  declare -a headings=("Table Name" "Records Count")
  declare -A tb

  row=0
  for tb in "$dbms_dir"/"$database_name"/*; do
    if [[ -f $tb ]]; then
      local tb_name=$(sed -n "s+${dbms_dir}/${database_name}/++gp" <<< $tb)
      # local tb_name=${tb##*/}
      # make sure that it's not the meta file
      if [[ "$tb_name" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        tb["$row,0"]="$tb_name"
        tb["$row,1"]="$(($(cat "$dbms_dir"/"$database_name"/"$tb_name" | wc -l) - 1))"
        ((row++))
      fi
    fi
  done
  print_table "${#headings[@]}" "${row}" "${headings[@]}" "$(declare -p tb)"

  echo ""
}

# parameter 1: connected database name
# parameter 2: table name to drop
# returns 4 if table name is not valid
# returns 5 if table doesn't exisits
handle_drop_query() {
  local database_name="${1}"
  local query="${2,,}"
  local table_name

  #                       -------------------------
  # 1. will match this -> |drop table   table_name|
  #                       -------------------------
  local drop_table_pattern="^drop\s+table\s+($name_pattern)"


  if [[ "$query" =~ $drop_table_pattern ]]; then
    table_name="${BASH_REMATCH[1]}"

    check_name_validity "$table_name"
    if [[ ! $? -eq 0 ]]; then
      print_error 4 "$table_name"
      return 4
    fi

    if [ -f "${dbms_dir}/${database_name}/${table_name}" ]; then
      rm "${dbms_dir}/${database_name}/${table_name}"
      rm "${dbms_dir}/${database_name}/_${table_name}"
      echo -e "${GREEN}Removed table ${table_name}${NC}"
      echo ""
    else
      print_error 5 "${table_name}"
      return 5
    fi
  else
    print_error 7
  fi
}

# parameter 1: connected database name
# parameter 2: sql create query
# returns 4 if table name is not valid
# returns 6 if table already exisits
# TODO: fix two primary keys at the same time in the creation query
# TODO: Handle spaces 
handle_create_query() {
  local database_name="${1}"
  local query="${2,,}"
  local meta_table=""

  local create_regexp="^create\s+table\s+([a-zA-Z]\w*)\s*\("
  local create_content_regexp="\s*($name_pattern)\s+(int|varchar)(\s+primary key)?\s*(,|\)$)"

  if [[ "$query" =~ $create_regexp ]]; then
    local query_content="${query#*\(}"
    local tb_name="${BASH_REMATCH[1]}"

    declare -a matches
    while true; do
      if [[ "$query_content" =~ $create_content_regexp ]]; then
        matches+=("${BASH_REMATCH[@]}")
        # delete each matched string to run the next match.
        query_content=$(sed -n -r "s/${create_content_regexp}//p" <<< $query_content)
      else
        break
      fi
    done
    # if query content is zero then it all matched the pattern then the 
    # syntax is correct
    if [ -z "$query_content" ]; then
      local sz="${#matches[@]}"

      local skip="t"
      for((i = 0; i < sz; i++)); do

        if [[ "$skip" == "t" ]]; then
          skip="f"
          continue
        fi

        # remove trailing and leading white spaces
        matches[$i]=$(sed 's/^[ \t]*//;s/[ \t]*$//' <<< ${matches[$i]})

        # skip empty matches (for some reason) TODO: figure out why
        if [[ -z ${matches[$i]} ]]; then continue; fi

        # end of table creation
        if [[ "${matches[$i]}" == ")" ]]; then break; fi

        # process next column (make count = 0)
        if [[ "${matches[$i]}" == "," ]]; then
          skip="t"
          meta_table=${meta_table%:}
          meta_table+="\n"
          continue
        fi

        meta_table+="${matches[$i]}:"
      done
      meta_table=${meta_table%:}

      # create table
      if [ ! -f "${dbms_dir}/${database_name}/${tb_name}" ]; then
        touch "${dbms_dir}/${database_name}/${tb_name}"
        touch "${dbms_dir}/${database_name}/_${tb_name}"
        echo -e "$meta_table" > "${dbms_dir}/${database_name}/_${tb_name}"

        # TODO: seperate this as a seperate helper function
        place_holder=$(awk -F : '
        {
          print $1
        }
        ' < "${dbms_dir}/${database_name}/_${tb_name}" | tr '\n' ':')
        place_holder=${place_holder%:}
        echo -e "$place_holder" >> "${dbms_dir}/${database_name}/${tb_name}"

        echo -e "${GREEN}Table \"$tb_name\" was created${NC}"
        echo ""
      else
        print_error 6 "${tb_name}"
        return 6
      fi

    else
      print_error 7
      return 7
    fi

  else
    print_error 7
    return 7
  fi

  # check_name_validity "${tb_name}"
  # if [ "$?" -eq 0 ]; then
  #   if [ ! -f "${dbms_dir}/${database_name}/${tb_name}" ]; then
  #
  #     touch "${dbms_dir}/${database_name}/${tb_name}"
  #     touch "${dbms_dir}/${database_name}/_${tb_name}"
  #     sleep 1
  #     echo -e "${GREEN}Created table\"$tb_name\"${NC}"
  #   else
  #     print_error 6 "${tb_name}"
  #     return 6
  #   fi
  # else
  #   print_error 4 "${tb_name}"
  #   return 4
  # fi
  # echo ""
}


# parameter 1: connected database name
# parameter 2: sql insert query
# returns 4 if table name is not valid
# returns 5 if table doesn't exisit
# returns 7 if syntax error
# returns ? if column doesn't exisit
# TODO: sql supports ; as end of statement (maybe support it)
handle_insert_query() {
  local database_name="${1}"
  local query="${2,,}"


  # this is how we implement the regex 'g' flag using a loop
  # The idea is to do the following
  # 1. match the string to the pattern
  # 2. get the match
  # 3. remove the acquired match from the input string
  # 4. trim the string
  # 5. do step 1

  #                       ----------------------------
  # 1. will match this -> |insert   into   table_name|
  #                       ----------------------------
  local insert_into_table_pattern="^insert\s+into\s+($name_pattern)"

  #                       ------------------------
  # 2. will match this -> |( c1, c2  , c3 , c5  )|
  #                       ------------------------
  local column_names_pattern="^\((\s*($name_pattern)\s*(,|\)))+"
  #                       --------
  # 3. will match this -> |values|
  #                       --------
  local values_pattern='^values'
  
  #                       -------------------------------
  # 4. will match this -> |(  'value1', 123, '#2value2')|
  #                       -------------------------------
  local column_values_pattern="^\((\s*($value_pattern)\s*(,|\)$))+"

  local table_name
  declare -a matches

  query=$(trim_string "$query")
  if [[ "$query" =~ $insert_into_table_pattern ]]; then
    table_name="${BASH_REMATCH[1]}"
    query=$(sed -n -r "s/${insert_into_table_pattern}//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  query=$(trim_string "$query")
  if [[ "$query" =~ $column_names_pattern ]]; then
    matches+=("${BASH_REMATCH[0]}")
    query=$(sed -n -r "s/${column_names_pattern}//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  query=$(trim_string "$query")
  if [[ "$query" =~ $values_pattern ]]; then
    query=$(sed -n -r "s/${values_pattern}//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  # we used grep here to compare against a query
  # that includes single quotes that make bash complain.
  query=$(trim_string "$query")
  match=$(echo "$query" | grep -P "$column_values_pattern")
  if [[ -n "$match" ]]; then
    matches+=("$match")
    query=$(sed -n -r "s/$column_values_pattern//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  if [[ -n "$query_content" ]]; then
    print_error 7
    return 7
  fi

  ##########################################################################################

  check_name_validity "$table_name"
  if [[ ! $? -eq 0 ]]; then
    print_error 4 "$table_name"
    return 4
  fi

  if [[ ! -f "${dbms_dir}/${database_name}/${table_name}" ]]; then
    print_error 5 "$table_name"
    return 5
  fi

  local column_names_matched_string="${matches[0]}"
  local column_names
  tokenize_column_names "$column_names_matched_string" column_names

  local values_matched_string="${matches[1]}"
  local values
  tokenize_values "$values_matched_string" values

  check_columns_values_count "${#column_names[@]}" "${#values[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi
  check_columns_names "${#column_names[@]}" "${column_names[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi
  check_data_types "${database_name}" "${table_name}" "${#column_names[@]}" "${column_names[@]}" "${#values[@]}" "${values[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi
  check_primary_key "${database_name}" "${table_name}" "${#column_names[@]}" "${column_names[@]}" "${#values[@]}" "${values[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  local sz="${#column_names[@]}"
  for((i = 0; i < sz; i++)); do
    local column_name="${column_names[$i]}"
    local value="${values[$i]}"
    sed -i "\$s/${column_name}/${value}/" "${dbms_dir}/${database_name}/${table_name}"
  done
  place_holder=$(awk -F : '
  {
    print $1
  }
  ' < "${dbms_dir}/${database_name}/_${table_name}" | tr '\n' ':')
  place_holder=${place_holder%:}
  echo -e "$place_holder" >> "${dbms_dir}/${database_name}/${table_name}"

}


# parameter 1: connected database name
# parameter 2: sql delete query
# returns 4 if table name is not valid
# returns 5 if table doesn't exisit
# TODO: sql supports ; as end of statement (maybe support it)
# TODO: make sure that anyname used in the query is not one of the 
# sql language keywords.
handle_delete_query() {
  local database_name="${1}"
  local query="${2,,}" # this handles if user entered query uppercase

  # this is how we implement the regex 'g' flag using a loop
  # The idea is to do the following
  # 1. match the string to the pattern
  # 2. get the match
  # 3. remove the acquired match from the input string
  # 4. trim the string from any leading or trailing whitespaces 
  # 5. start from step 1 with the next pattern

  #                       ----------------------------
  # 1. will match this -> |delete   from   table_name|
  #                       ----------------------------
  local delete_from_table_pattern='^delete\s+from\s+([a-zA-Z]\w*)'

  #                       ---------------------------------
  # 2. will match this -> |where column_name     >     12 |
  #                       ---------------------------------
  local where_condition_pattern="^where\s+([a-zA-Z][a-zA-Z0-9_]*)[[:space:]]*(=|!=|>|<|>=|<=)[[:space:]]*('[^']*'|[0-9]+)"

  local table_name
  local column_name
  local logical_operator
  local value

  query=$(trim_string "$query")
  if [[ "$query" =~ $delete_from_table_pattern ]]; then
    table_name="${BASH_REMATCH[1]}"
    query=$(sed -n -r "s/${delete_from_table_pattern}//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  query=$(trim_string "$query")
  if [[ $query =~ $where_condition_pattern ]]; then
    column_name="${BASH_REMATCH[1]}"
    logical_operator="${BASH_REMATCH[2]}"
    value="${BASH_REMATCH[3]}"
    query=$(sed -n -r "s/${where_condition_pattern}//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  if [[ -n "$query_content" ]]; then
    print_error 7
    return 7
  fi

  #############################################

  echo "Column Name:" "$column_name"
  echo "Logical Operator:" "$logical_operator"
  echo "Value" "$value"
}

# parameter 1: connected database name
# parameter 2: sql select query
# returns 4 if table name is not valid
# returns 5 if table doesn't exisit
# returns 7 if syntax error
# returns 11 if column doesn't exist
# returns 12 if column name is invalid
# TODO: sql supports ; as end of statement (maybe support it)
# TODO: make sure that anyname used in the query is not one of the 
# sql language keywords.
handle_select_query() {
  local database_name="${1}"
  local query="${2}"
  local table_name

  #                       ---------
  # 1. will match this -> |select |
  #                       ---------

  local select_pattern="^select"

  #                       ------------------------
  # 2. will match this -> |( c1, c2  , * , c5  ) |
  #                       ------------------------
  local select_column_names_pattern="^\((\s*($name_pattern|\*)\s*(,|\)))+"


  #                       ------------------------
  # 3. will match this -> | from     table_name  |
  #                       ------------------------
  
  #TODO: seperate the name pattern in a global variable
  local from_table_pattern="^from\s+($name_pattern)"


  ###############  1. CECHK SYNTAX  #########################
 query=$(trim_string "$query")
  echo "query input to 1st pattern: $query"
  if [[ "$query" =~ $select_pattern ]]; then
    query=$(sed -n -r "s/${select_pattern}//p" <<< "$query")
  else
    echo "ana klmt select"
    print_error 7
    return 7
  fi

  query=$(trim_string "$query")
  echo "query input to 2nd pattern: $query"
  if [[ "$query" =~ $select_column_names_pattern ]]; then
    matched_column_names="${BASH_REMATCH[0]}"
    echo "column names: $column_names"
    query=$(sed -n -r "s/${select_column_names_pattern}//p" <<< "$query")
  else
    echo "ana column names" 
    print_error 7
    return 7
  fi

  query=$(trim_string "$query")
  echo "from table input: $query"
  if [[ "$query" =~ $from_table_pattern ]]; then
    table_name="${BASH_REMATCH[1]}"
    echo "table name: $table_name"
    query=$(sed -n -r "s/${from_table_pattern}//p" <<< "$query")
  else
    echo " table name"
    print_error 7
    return 7
  fi

  ###############  2. CECHK TABLE NAME   ####################
  check_name_validity "$table_name"
  if [[ ! $? -eq 0 ]]; then
    print_error 4 "$table_name"
    return 4
  fi

  ###############  3. CECHK TABLE DOESN'T EXISIT  ###########
  if [[ ! -f "${dbms_dir}/${database_name}/${table_name}" ]]; then
    print_error 5 "$table_name"
    return 5
  fi

  ###############  4. CECHK COLUMN NAMES + SEE IF IT DOESN'T EXISIT ##########

  # TOKENIZE
  local column_names
  tokenize_column_names "$matched_column_names" column_names
  echo "CCCCCC" "${#column_names[@]}" "${column_names[@]}"
  check_columns_names "${#column_names[@]}" "${column_names[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  ###############  5. CECHK IF ASTRIX IS ALONE OR NOT  ##########
  if [[ "${#column_names[@]}" > 1 ]]; then
    for column_name in "${column_names[@]}"; do
      if [[ "$column_name" == "*" ]]; then
        print_error 13
        return 13
      fi
    done
  fi

  ###############  6. LOGIC   ##################################
  local meta_table_path="${dbms_dir}/${database_name}/_${table_name}"
  local table_path="${dbms_dir}/${database_name}/${table_name}"
  local records_sz=$(($(cat ${table_path} | wc -l) - 1))
  local column_name
  local column_number
  local column_sz
  local values_sz
  local value
  local key

  declare -A data
  
  columns_sz="${#column_names[@]}"
  if [[ "$columns_sz" == 1 && "${column_names[0]}" == "*" ]]; then
    column_names=($(tail -1 ${table_path} | tr ':' ' '))
  fi

  columns_sz="${#column_names[@]}"
  for((i = 0; i < columns_sz; i++)); do
    column_name="${column_names[$i]}"
    column_number=$(awk -F : -v column_name="$column_name" ' 
    {
      if($1 == column_name){
        print FNR
      }
    }
    ' < "${meta_table_path}")

    declare -a values=($(awk -F : -v column_number="$column_number" ' 
    {
      print $column_number
    }
    ' < "${table_path}"))

    values_sz="${#values[@]}"
    for((j = 0; j < values_sz-1; j++)); do
      value="${values[$j]}"
      key="$j,$i"
      data["$key"]="$value"
    done

  done

  print_table "$columns_sz" "$records_sz" "${column_names[@]}" "$(declare -p data)"

}
# TODO: 

# 2. insert (1 day: 4hours, )





# TODO: 

# 2. insert (1 day: 4hours, )
# 3. select (1 day)
# 4. delete (logic)
# 5. update (syntax+logic)

