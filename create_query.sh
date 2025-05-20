#! /usr/bin/bash
source utils.sh

# parameter 1: connected database name
# parameter 2: sql create query
# returns 4 if table name is not valid
# returns 6 if table already exisits
# returns 7 if syntax error
# returns 12 if column name is invalid
# returns 16 if primary key is repeated
# TODO: Can't have more than one column with the same name
handle_create_query() {
  local database_name="${1}"
  local query="${2}"
  local create_matched_paren # will hold this (c1, c2, c4)
  local meta_table
  local number_of_columns


  #################### 1. CHECK SYNTAX ####################
  #                       ----------------------------
  # 1. will match this -> |create   table  table_name|
  #                       ----------------------------

  local create_regexp="^create[[:space:]]+table[[:space:]]+($name_pattern)"
  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ "$query" =~ $create_regexp ]]; then
    table_name="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[1]}")"
    query=$(sed -n -r "s/$create_regexp//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  #                       ------------------------------------------------------------
  # 2. will match this -> |(  c1 int primary    key  , invalid name int ,  c3 , c5  )|
  #                       ------------------------------------------------------------

  local create_content_regexp="^\(([[:space:]]*($name_pattern)[[:space:]]+(int|varchar)([[:space:]]+primary[[:space:]]+key)?[[:space:]]*)(,[[:space:]]*($name_pattern)[[:space:]]+(int|varchar)([[:space:]]+primary[[:space:]]+key)?[[:space:]]*)*\)$"
  query=$(remove_leading_trailing_whitespaces "$query")
  if [[ $query =~ $create_content_regexp ]]; then
    create_matched_paren="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[0]}")"
    query=$(sed -n -r "s/$create_content_regexp//p" <<< "$query")
  else
    print_error 7
    return 7
  fi

  #################### 2. CHECK TABLE NAME VALIDITY ####################
  check_name_validity "$table_name"
  if [[ ! $? -eq 0 ]]; then
    print_error 4 "$table_name"
    return 4
  fi

  #################### 3. CHECK IF TABLE ALREADY EXISTS ####################
  if [ -f "${dbms_dir}/${database_name}/${table_name}" ]; then
    print_error 6 "$table_name"
    return 6
  fi

  #################### 4. GET ONLY COLUMN NAMES ( c1 , c2  ) ####################
  local create_matched_paren_column_names=$create_matched_paren
  create_matched_paren_column_names=$(sed "s/varchar//g" <<< $create_matched_paren_column_names)
  create_matched_paren_column_names=$(sed "s/int//g" <<< $create_matched_paren_column_names)
  create_matched_paren_column_names=$(sed "s/primary//g" <<< $create_matched_paren_column_names)
  create_matched_paren_column_names=$(sed "s/key//g" <<< $create_matched_paren_column_names)

  #################### 5. TOKENIZE COLUMN NAMES ####################
  local column_names
  tokenize_column_names "$create_matched_paren_column_names" column_names
  local number_of_columns="${#column_names[@]}"

  #################### 6. GET ONLY COLUMN TYPES ( int , varchar  ) ####################
  local create_matched_paren_column_types=$create_matched_paren
  create_matched_paren_column_types=$(sed "s/primary//g" <<< $create_matched_paren_column_types)
  create_matched_paren_column_types=$(sed "s/key//g" <<< $create_matched_paren_column_types)
  for column_name in "${column_names[@]}"; do
    create_matched_paren_column_types=$(sed "s/$column_name//g" <<< $create_matched_paren_column_types)
  done
  #################### 7. TOKENIZE COLUMN TYPES ####################
  local column_types
  tokenize_column_names "$create_matched_paren_column_types" column_types

  #################### 8. GET ONLY PRIMARY KEY KEYWORD ( primary key, primary key ) ####################
  local create_matched_paren_primary_key=$create_matched_paren
  for column_name in "${column_names[@]}"; do
    create_matched_paren_primary_key=$(sed "s/$column_name//g" <<< $create_matched_paren_primary_key)
  done
  for column_type in "${column_types[@]}"; do
    create_matched_paren_primary_key=$(sed "s/$column_type//g" <<< $create_matched_paren_primary_key)
  done

  #################### 9. TOKENIZE PRIMARY KEYS ####################
  local column_primary_keys
  tokenize_column_names "$create_matched_paren_primary_key" column_primary_keys

  #################### 10. CHECK COLUMN NAMES VALIDITY ####################
  check_columns_name_validity "${#column_names[@]}" "${column_names[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  #################### 11. CHECK IF A COLUMN NAME WAS repeated ####################
  check_repeated_column_name "${column_names[@]}"
  if [ ! "$?" -eq 0 ]; then return "$?"; fi

  #################### 12. CHECK MULTIPLE PRIMARY KEYS ####################
  if [[ ${#column_primary_keys[@]} > 1 ]]; then
    print_error 16 
    return 16
  fi

  
  ####################           LOGIC           ####################
  
  #################### 1. WHICH COLUMN IS PRIMARY KEY   ####################
  local primary_key_column_name
  for (( i=0 ; i < number_of_columns; i++)); do
    field_str=$(cut -d "," -f $((i+1)) <<< "$create_matched_paren")
    echo "$field_str" | grep "primary"
    if [[ "$?" == 0 ]]; then
      primary_key_column_name="${column_names[$i]}"
      break
    fi
  done

  #################### 2. CREATE THE NEW TABLE ####################
  local meta_data=""
  for (( i=0 ; i < number_of_columns; i++)); do
    local column_name="${column_names[$i]}"
    local column_type="${column_types[$i]}"
    meta_data+="${column_name}:${column_type}"
    if [[ "$column_name" == "$primary_key_column_name" ]]; then
      meta_data+=":primary key"
    fi
    # only add "\n" if not last line
    if [[ $((i+1)) != "$number_of_columns" ]]; then
      meta_data+="\n"
    fi
  done

  touch "${dbms_dir}/${database_name}/${table_name}"
  touch "${dbms_dir}/${database_name}/_${table_name}"
  echo -e "$meta_data" > "${dbms_dir}/${database_name}/_${table_name}"

  #################### 3. PUT THE PALCE HOLDER AT END OF TABLE ##############################
  place_holder=$(awk -F : '
  {
    print $1
  }
  ' < "${dbms_dir}/${database_name}/_${table_name}" | tr '\n' ':')
  place_holder=${place_holder%:}
  echo -e "$place_holder" >> "${dbms_dir}/${database_name}/${table_name}"

  #################### 4. SUCCESSFUL ECO ####################
  echo -e "${GREEN}Table \"$table_name\" was created${NC}"
  echo ""

}
