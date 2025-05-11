#! /usr/bin/bash
source utils.sh

# parameter 1: database name
list_tables () {
  db_name="$1"

  declare -a headings=("Table Name" "Records Count")
  declare -A tb

  row=0
  for tb in "$dbms_dir"/"$db_name"/*; do
    if [[ -f $tb ]]; then
      local tb_name=$(sed -n "s+${dbms_dir}/${db_name}/++gp" <<< $tb)
      # local tb_name=${tb##*/}
      # make sure that it's not the meta file
      if [[ "$tb_name" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        tb["$row,0"]="$tb_name"
        tb["$row,1"]="$(cat "$dbms_dir"/"$db_name"/"$tb_name" | wc -l)"
        ((row++))
      fi
    fi
  done
  print_table "${#headings[@]}" "${row}" "${headings[@]}" "$(declare -p tb)"

  echo ""
}

# parameter 1: connected database name
# parameter 2: table name to drop
# returns 4 if database name is not valid
# returns 5 if table doesn't exisits
drop_table() {
  db_name="${1}"
  tb_name="${2}"
  check_name_validity "${tb_name}"
  if [ "$?" -eq 0 ]; then
    if [ -f "${dbms_dir}/${db_name}/${tb_name}" ]; then
      rm "${dbms_dir}/${db_name}/${tb_name}"
      rm "${dbms_dir}/${db_name}/_${tb_name}"
      echo -e "${GREEN}Removed table ${tb_name}${NC}"
    else
      print_error 5 "${tb_name}"
      return 5
    fi
  else
      print_error 4 "${tb_name}"
      return 4
  fi
  echo ""
}

# parameter 1: connected database name
# parameter 2: sql create query
# returns 4 if table name is not valid
# returns 6 if table already exisits
create_table() {
  local db_name="${1}"
  local query="${2}"
  local meta_table=""

# ^create\s+table\s+([a-zA-Z]\w*)\s*\(
# /(\s*([a-zA-Z]\w*)\s+(int|varchar)(\s+primary key)?\s*(,|\)$))/gm
  local create_regexp='^create\s+table\s+([a-zA-Z]\w*)\s*\('
  local create_content_regexp='\s*([a-zA-Z]\w*)\s+(int|varchar)(\s+primary key)?\s*(,|\)$)'

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
      if [ ! -f "${dbms_dir}/${db_name}/${tb_name}" ]; then
        touch "${dbms_dir}/${db_name}/${tb_name}"
        touch "${dbms_dir}/${db_name}/_${tb_name}"
        echo -e "$meta_table" > "${dbms_dir}/${db_name}/_${tb_name}"
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
  #   if [ ! -f "${dbms_dir}/${db_name}/${tb_name}" ]; then
  #
  #     touch "${dbms_dir}/${db_name}/${tb_name}"
  #     touch "${dbms_dir}/${db_name}/_${tb_name}"
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
# parameter 2: sql create query
# returns 4 if table name is not valid
# returns 6 if table already exisits
# TODO: sql supports ; as end of statement (maybe support it)
insert_table() {
  local db_name="${1}"
  local query="${2}"


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
  local insert_into_table_pattern='^insert\s+into\s+([a-zA-Z]\w*)'

  #                       ------------------------
  # 2. will match this -> |( c1, c2  , c3 , c5  )|
  #                       ------------------------
  local column_names_pattern='^\((\s*([a-zA-Z]\w*)\s*[,)])+'

  #                       --------
  # 3. will match this -> |values|
  #                       --------
  local values_pattern='^values'
  
  #                       -------------------------------
  # 4. will match this -> |(  'value1', 123, '#2value2')|
  #                       -------------------------------
  local column_values_pattern="^\((\s*('[^']*'|\d+)\s*[,)])+"
  quote="'"


  local tb_name
  declare -a matches

  query=$(trim_string "$query")
  echo "query input to 1st pattern: $query"
  if [[ "$query" =~ $insert_into_table_pattern ]]; then
    tb_name="${BASH_REMATCH[1]}"
    query=$(sed -n -r "s/${insert_into_table_pattern}//p" <<< "$query")
  else
    echo "ana 2wl 7ta"
    print_error 7
    return 7
  fi

  query=$(trim_string "$query")
  echo "query input to 2nd pattern: $query"
  if [[ "$query" =~ $column_names_pattern ]]; then
    matches+=("${BASH_REMATCH[0]}")
    query=$(sed -n -r "s/${column_names_pattern}//p" <<< "$query")
  else
    echo "ana column names"
    print_error 7
    return 7
  fi

  query=$(trim_string "$query")
  echo "query input to 3rd pattern: $query"
  if [[ "$query" =~ $values_pattern ]]; then
    query=$(sed -n -r "s/${values_pattern}//p" <<< "$query")
  else
    echo "ana klmt values"
    print_error 7
    return 7
  fi

  # we used grep here to compare against a query
  # that includes single quotes that make bash complain.
  query=$(trim_string "$query")
  echo "query input to 4th pattern: $query"
  match=$(echo "$query" | grep -P "$column_values_pattern")
  if [[ -n "$match" ]]; then
    matches+=("$match")
    query=$(sed -n -r "s/$column_values_pattern//p" <<< "$query")
  else
    echo "ana column values"
    print_error 7
    return 7
  fi

  if [[ -n "$query_content" ]]; then
    echo "ana lsa fya klam"
    print_error 7
    return 7
  fi

  #############################################

  echo "${matches[@]}"
}



# TODO: 

# 2. insert (1 day: 4hours, )
# 3. select (1 day)
# 4. delete (1 day)
# 5. update (1 day)

