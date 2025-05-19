#! /usr/bin/bash

source utils.sh
source regexp.sh

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
  local column_names_pattern="^\(([[:space:]]*($name_pattern)[[:space:]]*)(,[[:space:]]*($name_pattern)[[:space:]]*)*\)"
  #                       --------
  # 3. will match this -> |values|
  #                       --------
  local values_pattern="^values"
  
  #                       -------------------------------
  # 4. will match this -> |(  'value1', 123, '#2value2')|
  #                       -------------------------------
  local column_values_pattern="^\(([[:space:]]*($value_pattern)[[:space:]]*)(,[[:space:]]*($value_pattern)[[:space:]]*)*\)$"

  local table_name
  declare -a matches

  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ "$query" =~ $insert_into_table_pattern ]]; then
    table_name="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[1]}")"
    query=$(sed -n -r "s/${insert_into_table_pattern}//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ "$query" =~ $column_names_pattern ]]; then
    matches+=("$(remove_leading_trailing_whitespaces "${BASH_REMATCH[0]}")")
    query=$(sed -n -r "s/${column_names_pattern}//p" <<< "$query")
  else
    echo "MEEE"
    print_error 7
    return 7
  fi

  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ "$query" =~ $values_pattern ]]; then
    query=$(sed -n -r "s/${values_pattern}//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  # we used grep here to compare against a query
  # that includes single quotes that make bash complain.
  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ $query =~ $column_values_pattern ]]; then
    matches+=("$(remove_leading_trailing_whitespaces "${BASH_REMATCH[0]}")")
    query=$(sed -n -r "s/$column_values_pattern//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  if [[ -n "$query" ]]; then
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
  check_repeated_column_name "${column_names[@]}"
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
