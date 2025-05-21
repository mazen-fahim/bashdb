#! /usr/bin/bash

source utils.sh

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
  local query="${2,,}" 
  local table_name
  local column_name
  local logical_operator
  local check_value

  #################### 1. CHECK SYNTAX   ####################
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

  #################### 2. CHECK TABLE NAME VALIDITY   ####################
  check_name_validity "$table_name"
  if [[ ! $? -eq 0 ]]; then
    print_error 4 "$table_name"
    return 4
  fi

  #################### 3. CHECK IF TABLE EXISTS      ####################
  if [[ ! -f "${dbms_dir}/${database_name}/${table_name}" ]]; then
    print_error 5 "$table_name"
    return 5
  fi

  #################### 4. CHECK COLUMN NAME VALIDITY  ####################
  check_columns_name_validity "1" "$column_name"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  #################### 5. CHECK IF COLUMN EXISTS      ####################
  check_columns_existence "$database_name" "$table_name" "1" "$column_name"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  #################### 6. CHECK IF THE THE COLUMN MATCHES THE DATA TYPE OF THE VALUE ####################
  check_data_types "${database_name}" "${table_name}" "1" "$column_name" "1" "$check_value"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  #################### 7. CHECK IF WE ARE DEALING WITH STRINGS SO THAT WE ONLY ALLOW ####################
  ####################    LOGICAL OPERATORS "=" AND "!="   ####################
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

  #################### 8. LOGIC  ####################
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

  local no_of_records_before_delete=$(($(cat "$table_path" | wc -l) - 1))
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
  ' "$table_path" "$table_path" > "${table_path}.tmp"
  local no_of_records_after_delete=$(cat "$table_path.tmp" | wc -l)
  local no_of_records_deleted=$((no_of_records_before_delete - no_of_records_after_delete))
  mv "${table_path}.tmp" "$table_path"
  echo -e "${GREEN}$no_of_records_deleted records are deleted.${NC}"
  echo ""


  # Don't forget to add the place holder after deleting
  place_holder=$(awk -F : '
  {
    print $1
  }
  ' < "${dbms_dir}/${database_name}/_${table_name}" | tr '\n' ':')
  place_holder=${place_holder%:}
  echo -e "$place_holder" >> "$table_path"

}
