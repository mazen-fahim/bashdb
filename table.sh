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
    table_name="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[1]}")"

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
    local tb_name="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[1]}")"

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
# returns 8: if column_count != values_count
# returns 9 if data types don't match 
# returns 10 if primary key value already exists
# returns 11: if column doesn't exsist
# returns 12: if column name is invalid
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
  # 2. will match this -> |(  c1  , c2  , c3 , c5  )|
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

  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ "$query" =~ $insert_into_table_pattern ]]; then
    table_name="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[1]}")"
    query=$(sed -n -r "s/${insert_into_table_pattern}//p" <<< "$query")
  else
    echo "ana 1"
    print_error 7
    return 7
  fi

  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ "$query" =~ $column_names_pattern ]]; then
    matches+=("$(remove_leading_trailing_whitespaces "${BASH_REMATCH[0]}")")
    query=$(sed -n -r "s/${column_names_pattern}//p" <<< "$query")
  else
    echo "ana 2"
    print_error 7
    return 7
  fi

  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ "$query" =~ $values_pattern ]]; then
    query=$(sed -n -r "s/${values_pattern}//p" <<< "$query")
  else
    echo "ana 3"
    print_error 7
    return 7
  fi

  # we used grep here to compare against a query
  # that includes single quotes that make bash complain.
  query=$(remove_leading_trailing_whitespaces "$query")
  match=$(echo "$query" | grep -P "$column_values_pattern")
  if [[ -n "$match" ]]; then
    matches+=("$(remove_leading_trailing_whitespaces "$match")")
    query=$(sed -n -r "s/$column_values_pattern//p" <<< "$query")
  else
    echo "ana 4"
    print_error 7
    return 7
  fi

  if [[ -n "$query" ]]; then
    echo "ana 5: $query"
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
  check_columns_name_validity "${#column_names[@]}" "${column_names[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi
  check_columns_existence "$database_name" "$table_name" "${#column_names[@]}" "${column_names[@]}"
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
# returns 7 if syntax error
# returns 9 if data types don't match 
# returns 11: if column doesn't exsist
# returns 12: if column name is invalid
# returns 14: if column type = value type but the logical operator is not supported for this type
# TODO: sql supports ; as end of statement (maybe support it)
# TODO: make sure that anyname used in the query is not one of the 
# sql language keywords.
handle_delete_query() {
  local database_name="${1}"
  local query="${2,,}" # this handles if user entered query uppercase
  local table_name
  local column_name
  local logical_operator
  local check_value

  ############ 1. CHECK SYNTAX                ######################
  #                       ---------------------------------------------------------
  # 1. will match this -> |delete   from   table_name where column_name > 'value' |
  #                       ---------------------------------------------------------
  local delete_query_pattern="^delete[[:space:]]+from[[:space:]]+([a-zA-Z][a-zA-Z0-9_ ]*)[[:space:]]+where[[:space:]]+([a-zA-Z][a-zA-Z0-9_ ]*)[[:space:]]*(>=|<=|!=|=|>|<)[[:space:]]*('[^']*'|[0-9]+)"
  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ $query =~ $delete_query_pattern ]]; then
    table_name="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[1]}")"
    column_name="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[2]}")"
    logical_operator="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[3]}")"
    check_value="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[4]}")"
    query=$(sed -n -r "s/${delete_query_pattern}//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  if [[ -n "$query" ]]; then
    print_error 7
    return 7
  fi

  ############ 2. CHECK TABLE NAME VALIDITY   ######################
  check_name_validity "$table_name"
  if [[ ! $? -eq 0 ]]; then
    print_error 4 "$table_name"
    return 4
  fi

  ############ 3. CHECK IF TABLE EXISTS       ######################
  if [[ ! -f "${dbms_dir}/${database_name}/${table_name}" ]]; then
    print_error 5 "$table_name"
    return 5
  fi

  ############ 4. CHECK COLUMN NAME VALIDITY  ######################
  check_columns_name_validity "1" "$column_name"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  ############ 5. CHECK IF COLUMN EXISTS      ######################
  check_columns_existence "$database_name" "$table_name" "1" "$column_name"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  ############ 6. CHECK IF THE THE COLUMN MATCHES THE DATA TYPE OF THE VALUE ########
  check_data_types "${database_name}" "${table_name}" "1" "$column_name" "1" "$check_value"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  ############ 7. CHECK IF WE ARE DEALING WITH STRINGS SO THAT WE ONLY ALLOW ########
  ############    LOGICAL OPERATORS "=" AND "!="                             ########
  local value_type
  if [[ "${check_value:0:1}" == "'" ]]; then
    value_type="varchar"
  else
    value_type="int"
  fi

  if [[ "$value_type" == "varchar" ]]; then
    if [[ "$logical_operator" != "=" && "$logical_operator" != "!=" ]]; then
      print_error 14 "$logical_operator"
      return 14
    fi
  fi

  ############ 8. LOGIC                       ######################
  local table_path="${dbms_dir}/${database_name}/${table_name}"
  local meta_table_path="${dbms_dir}/${database_name}/_${table_name}"
  local column_number
  declare -a values
  declare -A data

  column_number=$(awk -F : -v column_name="$column_name" ' 
  {
    if($1 == column_name){
      print FNR
    }
  }
  ' < "${meta_table_path}")

  awk -F : -v column_number="$column_number" -v logical_operator="$logical_operator" -v check_value="$check_value" '
  NR == FNR { total = NR; next }        # First pass: count total lines
  FNR == total { next }                 # Second pass: skip the last line
  {
    if (logical_operator == ">=" && $column_number >= check_value) next
    else if (logical_operator == "<=" && $column_number <= check_value) next
    else if (logical_operator == "!=" && $column_number != check_value) next
    else if (logical_operator == "="  && $column_number == check_value) next
    else if (logical_operator == ">"  && $column_number > check_value) next
    else if (logical_operator == "<"  && $column_number < check_value) next
    print
  }
  ' "$table_path" "$table_path" > "${table_path}.tmp" && mv "${table_path}.tmp" "$table_path"

  # Don't forget to add the place holder after deleting
  place_holder=$(awk -F : '
  {
    print $1
  }
  ' < "${dbms_dir}/${database_name}/_${table_name}" | tr '\n' ':')
  place_holder=${place_holder%:}
  echo -e "$place_holder" >> "$table_path"

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
  local matched_column_names
  local where_column_name
  local where_logical_operator
  local where_value

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
  local where_from_table_pattern="^from\s+($name_pattern)\s+where"

  #                       --------------------------------------
  # 4. will match this -> | where  column  name  >  ' value '  |
  #                       --------------------------------------
  local where_pattern="^([a-zA-Z][a-zA-Z0-9_ ]*)[[:space:]]*(>=|<=|!=|=|>|<)[[:space:]]*('[^']*'|[0-9]+)"

  ###############  1. CECHK SYNTAX  #########################
 query=$(remove_leading_trailing_whitespaces "$query")
  if [[ "$query" =~ $select_pattern ]]; then
    query=$(sed -n -r "s/${select_pattern}//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ "$query" =~ $select_column_names_pattern ]]; then
    matched_column_names="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[0]}")"
    echo "Matched Column Names : $matched_column_names"
    query=$(sed -n -r "s/${select_column_names_pattern}//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  local found_where
  echo "$query" | grep "where" > /dev/null
  if [[ "$?" == 0 ]]; then
    found_where="true"
  else
    found_where="false"
  fi

  if [[ "$found_where" == "false" ]]; then
    query=$(remove_leading_trailing_whitespaces "$query")
    if [[ "$query" =~ $from_table_pattern ]]; then
      table_name="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[1]}")"
      echo "Table Name: $table_name"
      query=$(sed -n -r "s/${from_table_pattern}//p" <<< "$query")
    else
      print_error 7
      return 7
    fi
  else
    query=$(remove_leading_trailing_whitespaces "$query")
    if [[ "$query" =~ $where_from_table_pattern ]]; then
      table_name="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[1]}")"
      echo "Table Name: $table_name"
      query=$(sed -n -r "s/${where_from_table_pattern}//p" <<< "$query")
    else
      print_error 7
      return 7
    fi

    query=$(remove_leading_trailing_whitespaces "$query")
    if [[ $query =~ $where_pattern ]]; then
      where_column_name="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[1]}")"
      where_logical_operator="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[2]}")"
      where_value="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[3]}")"
      echo "Where Column Name: $where_column_name"
      echo "Where Logical Operator: $where_logical_operator"
      echo "Where Value: $where_value"
      query=$(sed -n -r "s/${where_pattern}//p" <<< "$query")
    else
      print_error 7
      return 7
    fi
  fi

  if [[ -n "$query" ]]; then
    print_error 7
    return 7
  fi

  local meta_table_path="${dbms_dir}/${database_name}/_${table_name}"
  local table_path="${dbms_dir}/${database_name}/${table_name}"

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

  ###############  4. CECHK COLUMN NAMES VALIDITY                   ##########

  # TOKENIZE
  local column_names
  tokenize_column_names "$matched_column_names" column_names
  check_columns_name_validity "${#column_names[@]}" "${column_names[@]}"
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

  # If * is alone then expand it
  columns_sz="${#column_names[@]}"
  if [[ "$columns_sz" == 1 && "${column_names[0]}" == "*" ]]; then
    column_names=($(tail -1 ${table_path} | tr ':' ' '))
  fi

  ###############  6. CECHK COLUMN NAMES EXISTENCE                  ##########
  check_columns_existence "$database_name" "$table_name" "${#column_names[@]}" "${column_names[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  if [[ "$found_where" == "true" ]]; then
    ############ 7. CHECK WHERE COLUMN NAME VALIDITY  ######################
    check_columns_name_validity "1" "$where_column_name"
    if [ ! "$?" -eq 0 ]; then return "$?"; fi

    ############ 8. CHECK IF WHERE COLUMN NAME EXISTS      ######################
    check_columns_existence "$database_name" "$table_name" "1" "$where_column_name"
    if [ ! "$?" -eq 0 ]; then return "$?"; fi

    ############ 9. CHECK IF THE THE WHERE COLUMN MATCHES THE DATA TYPE OF THE WHERE VALUE ########
    check_data_types "${database_name}" "${table_name}" "1" "$where_column_name" "1" "$where_value"
    if [ ! "$?" -eq 0 ]; then return "$?"; fi

    ############ 10. CHECK IF WE ARE DEALING WITH STRINGS SO THAT WE ONLY ALLOW ########
    ############    LOGICAL OPERATORS "=" AND "!="                             ########
    local value_type
    if [[ "${where_value:0:1}" == "'" ]]; then
      value_type="varchar"
    else
      value_type="int"
    fi

    if [[ "$value_type" == "varchar" ]]; then
      if [[ "$where_logical_operator" != "=" && "$where_logical_operator" != "!=" ]]; then
        print_error 14 "$where_logical_operator"
        return 14
      fi
    fi
  fi

  ###############  11. LOGIC   ##################################
  local column_name
  local column_number
  local column_sz
  local values_sz
  local value
  local key

  declare -A data
  
  # Create the temp file that our select logic works on
  if [[ "$found_where" == "true" ]]; then
    local where_column_number=$(awk -F : -v where_column_name="$where_column_name" ' 
    {
      if($1 == where_column_name){
        print FNR
      }
    }
    ' < "${meta_table_path}")

    awk -F : -v where_column_number="$where_column_number" -v where_logical_operator="$where_logical_operator" -v where_value="$where_value" '
    NR == FNR { total = NR; next }        # First pass: count total lines
    FNR == total { next }                 # Second pass: skip the last line
    {
      if (where_logical_operator == ">=" && $where_column_number >= where_value) print
      else if (where_logical_operator == "<=" && $where_column_number <= where_value) print
      else if (where_logical_operator == "!=" && $where_column_number != where_value) print
      else if (where_logical_operator == "="  && $where_column_number == where_value) print
      else if (where_logical_operator == ">"  && $where_column_number > where_value) print 
      else if (where_logical_operator == "<"  && $where_column_number < where_value) print 
    }
    ' "$table_path" "$table_path" > "${table_path}.tmp"
  else
    cp "$table_path" "${table_path}.tmp"
    sed -i '$d' "${table_path}.tmp"
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
    ' < "${table_path}.tmp"))

    values_sz="${#values[@]}"
    for((j = 0; j < values_sz; j++)); do
      value="${values[$j]}"
      key="$j,$i"
      data["$key"]="$value"
    done

  done

  local records_sz=$(($(cat "${table_path}.tmp" | wc -l)))
  print_table "$columns_sz" "$records_sz" "${column_names[@]}" "$(declare -p data)"
  rm "${table_path}.tmp"

}
# TODO: 

# 2. insert (1 day: 4hours, )





# TODO: 

# 2. insert (1 day: 4hours, )
# 3. select (1 day)
# 4. delete (logic)
# 5. update (syntax+logic)

