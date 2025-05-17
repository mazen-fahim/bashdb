#! /usr/bin/bash
source utils.sh
source regexp.sh

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
