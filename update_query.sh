#! /usr/bin/bash

source utils.sh
source regexp.sh

# parameter 1: connected database name
# parameter 2: sql update query
# returns 4 : if table name is not valid
# returns 5 : if table doesn't exisit
# returns 7 : if syntax error
# return 9 : if data types don't match 
# returns 10: if primary key value already exists
# returns 11: if column doesn't exsist
# returns 12: if column name is invalid
# UPDATE table_name
# SET (column1 = value1, column2 = value2)
# WHERE condition;
# TODO: sql supports ; as end of statement (maybe support it)
# TODO: make sure that anyname used in the query is not one of the 
# sql language keywords.

handel_update_query(){
  local database_name="${1}"
  local query="${2}" # this handles if user entered query uppercase

  #                       -------------------------------
  # 1. will match this -> |update  table_name   set     |
  #                       -------------------------------
  local update_pattern="^update[[:space:]]+($name_pattern)[[:space:]]+set"

  #                       -----------------------------
  # 2. will match this -> |( c1 = 'value' , c2 = 2 )  |
  #                       -----------------------------
  local column_names_values_pattern="^\(([[:space:]]*($name_pattern)[[:space:]]*=[[:space:]]*($value_pattern)[[:space:]]*)(,[[:space:]]*($name_pattern)[[:space:]]*=[[:space:]]*($value_pattern)[[:space:]]*)*\)"
  

  #                       -----------------------------------------
  # 5. will match this -> | where     column_name >  2            |
  #                       -----------------------------------------
  local where_pattern="^where[[:space:]]+($name_pattern)[[:space:]]*(>=|<=|!=|=|>|<)[[:space:]]*($value_pattern)"

  ###############  1. CHECK SYNTAX  #########################

  local table_name
  local update_matched_paren
  local where_column_name 
  local where_logical_operator
  local where_value

  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ "$query" =~ $update_pattern ]]; then
    table_name="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[1]}")"
    query=$(sed -n -r "s/$update_pattern//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ "$query" =~ $column_names_values_pattern ]]; then
    update_matched_paren="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[0]}")"
    query=$(sed -n -r "s/${column_names_values_pattern}//p" <<< "$query")
  else

    echo "ana 2 ${query}"
    print_error 7
    return 7
  fi

  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ "$query" =~ $where_pattern ]]; then
    where_column_name="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[1]}")"
    where_logical_operator="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[2]}")"
    where_value="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[3]}")"
    query=$(sed -n -r "s/${where_pattern}//p" <<< "$query")
  else
    echo "ana 2 ${query}"
    print_error 7
    return 7
  fi

  if [[ -n "$query" ]]; then
    print_error 7
    return 7
  fi
  
  local table_path="${dbms_dir}/${database_name}/${table_name}"
  local meta_table_path="${dbms_dir}/${database_name}/_${table_name}"

  ####################  2. CHECK TABLE NAME validity   ####################
  check_name_validity "$table_name"
  if [[ ! $? -eq 0 ]]; then
    print_error 4 "$table_name"
    return 4
  fi

  #################### 3. CHECK TABLE DOESN'T EXIST        ####################
  if [[ ! -f "${dbms_dir}/${database_name}/${table_name}" ]]; then
    print_error 5 "$table_name"
    return 5
  fi

  #################### 4. CHECK COLUMN NAMES VALIDITY   ####################
  local tokenized_data
  local column_names
  tokenize_column_names_and_values "$matches" tokenized_data
  extract_column_names tokenized_data column_names
  check_columns_name_validity "${#column_names[@]}" "${column_names[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  ####################  5. CHECK COLUMN NAMES EXISTENCE  ####################
  check_columns_existence "$database_name" "$table_name" "${#column_names[@]}" "${column_names[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi


  ####################  5. CHECK DATA TYPES   ####################
  local column_value
  tokenize_column_names_and_values "$matches" tokenized_data
  extract_column_value tokenized_data column_value
  check_columns_values_validity "${#column_value[@]}" "${column_value[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi
  
  check_data_types "${database_name}" "${table_name}" "${#column_names[@]}" "${column_names[@]}" "${#column_value[@]}" "${column_value[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi
  ####################  6. CHECK PRIMARY KEY   ####################
  check_primary_key "${database_name}" "${table_name}" "${#column_names[@]}" "${column_names[@]}" "${#column_value[@]}" "${column_value[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi
  
  ####################           LOGIC           ####################
  #################### you still here keep going ####################


}
