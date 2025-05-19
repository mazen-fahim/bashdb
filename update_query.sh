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
  local where_found="true"
  if [[ -z $query ]]; then
    where_found="false"
  fi

  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ "$where_found" == "true" && "$query" =~ $where_pattern  ]]; then
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

  #################### 4. TOKENIZE COLUM NAMES AND VALUES  ####################
  local tokenized_data
  local column_names
  local column_indecies # array holding column indecies into the main table starting from 1
  local column_values
  tokenize_column_names_and_values "$update_matched_paren" tokenized_data
  extract_column_names tokenized_data column_names
  extract_column_value tokenized_data column_values

  #################### 5. CHECK COLUMN NAMES VALIDITY   ####################
  check_columns_name_validity "${#column_names[@]}" "${column_names[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  ####################  6. CHECK COLUMN NAMES EXISTENCE  ####################
  check_columns_existence "$database_name" "$table_name" "${#column_names[@]}" "${column_names[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  ####################  7. CHECK IF A COLUMN NAME IS REPEATED  ##############
  check_repeated_column_name "${column_names[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  ####################  8. CHECK DATA TYPES   ####################
  check_data_types "${database_name}" "${table_name}" "${#column_names[@]}" "${column_names[@]}" "${#column_values[@]}" "${column_values[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  ####################  9. CHECK PRIMARY KEY   ####################
  check_primary_key "${database_name}" "${table_name}" "${#column_names[@]}" "${column_names[@]}" "${#column_values[@]}" "${column_values[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi
  
  ####################           LOGIC           ####################
  # Get the primary key column
  local primary_key_column_name=$(awk -F : ' 
  {
    if($3 == "primary key"){
      print $1
    }
  }
  ' < "${meta_table_path}")

  # find out if one of the columns given in the update query
  # was the primary key column. because if so, we need to handle
  # the logic of such a case.
  local primary_key_column_found="false"
  for column_name in "${column_names[@]}";do
    if [[ "$column_name" == "$primary_key_column_name" ]]; then
      primary_key_column_found="true"
      break
    fi
  done

  # Get the position of each column in the table (is it the 1st column? the 2nd?
  # the 3rd? ... and so on. the answer will be in the column_indecies array
  for column_name in "${column_names[@]}";do
    column_indecies+=("$(awk -F : -v column_name="$column_name" ' 
    {
      if($1 == column_name){
        print FNR # represents the column index
      }
    }
    ' < "${meta_table_path}")")
  done
  
  # Get the position of the where condition column in the table (is it the 1st column? the 2nd?
  # the 3rd? ... and so on.
  local where_column_number=$(awk -F : -v where_column_name="$where_column_name" ' 
  {
    if($1 == where_column_name){
      print FNR
    }
  }
  ' < "${meta_table_path}")

  # convert the column_indecies array to a string seperated by ,
  # convert the column_values array to a string seperated by ,
  # so awk can operate on them
  local column_indecies_str=$(IFS=','; echo "${column_indecies[*]}")
  local column_values_str=$(IFS=','; echo "${column_values[*]}")


  # only keep the records that didn't pass the where condition in the main table.
  awk -F : -v where_column_number="$where_column_number" -v where_logical_operator="$where_logical_operator" -v where_value="$where_value" '
  NR == FNR { total = NR; next }        # First pass: count total lines
  FNR == total { next }                 # Second pass: skip the last line
  {
    if (where_logical_operator == ">=" && $where_column_number >= where_value) next
    else if (where_logical_operator == "<=" && $where_column_number <= where_value) next
    else if (where_logical_operator == "!=" && $where_column_number != where_value) next
    else if (where_logical_operator == "="  && $where_column_number == where_value) next
    else if (where_logical_operator == ">"  && $where_column_number > where_value) next
    else if (where_logical_operator == "<"  && $where_column_number < where_value) next
    print
  }
  ' "$table_path" "$table_path" > "${table_path}.tmp1" 

  # Seperate all record that passed the where condition into a seperate .tmp file.
  awk -F : -v where_column_number="$where_column_number" -v where_logical_operator="$where_logical_operator" -v where_value="$where_value" '
  NR == FNR { total = NR; next }        # First pass: count total lines
  FNR == total { next }                 # Second pass: skip the last line
  {
    if (where_logical_operator == ">=" && $where_column_number >= where_value) {
      print
      $0=""
    }
    else if (where_logical_operator == "<=" && $where_column_number <= where_value) {
      print
    }
    else if (where_logical_operator == "!=" && $where_column_number != where_value) print
    else if (where_logical_operator == "="  && $where_column_number == where_value) print
    else if (where_logical_operator == ">"  && $where_column_number > where_value) print
    else if (where_logical_operator == "<"  && $where_column_number < where_value) print
  }
  ' "$table_path" "$table_path" > "${table_path}.tmp2"

  local number_of_records_passed_condition="$(cat "${table_path}.tmp2" | wc -l)"
  # This number must be 1 if the primary key column is one of the columns
  # in the column_names array
  if [[ "$primary_key_column_found" == "true" && $number_of_records_passed_condition > 1 ]];  then
    print_error 18 "$primary_key_column_name"
    return 18
  fi

  # Update the matching records
  awk -F: -v indices="$column_indecies_str" -v values="$column_values_str" -v OFS=":" '
    BEGIN {
      split(indices, idx_arr, ",")
      split(values, val_arr, ",")
      for (i in idx_arr) {
        updates[idx_arr[i]] = val_arr[i]
      }
    }
    {
      for (col in updates) {
        $col = updates[col]
      }
      print
    }
  ' "$table_path.tmp2" > "$table_path.tmp3"

  # # Combine the updated records with the non-matching ones
  cat "$table_path.tmp1" "$table_path.tmp3" > "$table_path"
  # put the palce holder
  place_holder=$(awk -F : '
  {
   print $1
  }
  ' < "$meta_table_path" | tr '\n' ':')
  place_holder=${place_holder%:}
  echo -e "$place_holder" >> "$table_path"

  echo -e "${GREEN}Modified $number_of_records_passed_condition records.${NC}"
  echo ""
  rm -f "$table_path.tmp1" "$table_path.tmp2" "$table_path.tmp3"
}
