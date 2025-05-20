#! /usr/bin/bash

# parameter 1: the string we want to tokenize something
#               like this  "(  ' hii  hi' , 123 , 'val'  )"
# parameter 2: an empty array to be populated by the
#              output of this function
# returns an array containg the values
#
source utils.sh

# parameter 1: the string to trim
remove_leading_trailing_whitespaces(){
  str="$1"
  str="${str%"${str##*[![:space:]]}"}"
  str="${str#"${str%%[![:space:]]*}"}"
  echo "$str"
}

tokenize_column_names(){
str="$1"
sz="${#str}"

local -n arr=$2

inside_column_name="false"
accum=""
for((i=0; i < sz; i++)); do
  char="${str:$i:1}"

  # ( c1,  * , c2 , c4  asdf )

  if [[ "$char" == "," ]]; then
    accum="${accum%"${accum##*[![:space:]]}"}"
    accum="${accum#"${accum%%[![:space:]]*}"}"

    arr+=("$accum")
    accum=""
    inside_column_name="false"
    continue
  fi

  # detect whether or not we are inside a single quote
  if [[ "$inside_column_name" == "false" && ("$char" =~ [a-zA-Z] || "$char" == "*") ]]; then
    accum+="$char"
    inside_column_name="true"
    continue
  fi

  if [[ "$inside_column_name" == "false" ]]; then
    if [[ "$char" == " " || "$char" == "(" || "$char" == ")" ]]; then 
      continue; 
    fi
  else
    # I'm a character in a single quote please take me. 
    accum+="$char"
  fi
done

if [[ -n "$accum" ]]; then 
  accum="${accum%)}"

  accum="${accum%"${accum##*[![:space:]]}"}"
  accum="${accum#"${accum%%[![:space:]]*}"}"

  arr+=("$accum")
fi

}

# ( 123 ,  'mazen' , 123 , 'asd asd asd' )
tokenize_values(){
str="$1"
sz="${#str}"

local -n arr=$2

inside_single_quotes="false"
accum=""
for((i=0; i < sz; i++)); do
  char="${str:$i:1}"

  if [[ "$char" == "," ]]; then
    arr+=("$accum")
    accum=""
    continue
  fi

  # detect whether or not we are inside a single quote
  if [[ "$char" == "'" ]]; then
    accum+="'"
    if [[ "$inside_single_quotes" == "false" ]]; then
      inside_single_quotes="true"
    else
      inside_single_quotes="false"
    fi
    continue
  fi

  if [[ "$inside_single_quotes" == "false" ]]; then
    # I'm NOT in
    if [[ "$char" == " " || "$char" == "(" || "$char" == ")" ]]; then 
      continue; 
    else
      # HEY I"M A DIGIT PLEASE TAKE ME
      accum+="$char"
    fi
  else
    # I'm a character in a single quote please take me. 
    accum+="$char"
  fi
done
if [[ -n "$accum" ]]; then arr+=("$accum"); fi

}

# parameter 1: column_count
# parameter 2: values_count 
# returns 8: if column_count != values_count
check_columns_values_count(){
  # GET ARGUMENTS
  local column_count="$1"
  local value_count="$2"

  if [[ "$column_count" != "$value_count" ]]; then
    print_error 8
    return 8
  fi

  return 0
}

# parameter 1: column_count
# parameter 2: column_names (array expanded)
# returns 12: if column name is invalid
check_columns_name_validity(){
  # GET ARGUMENTS
  local column_count="$1"
  declare -a column_names
  for((i=0, idx = 2; i<column_count; i++, idx++));do
    column_names+=("${!idx}")
  done

  for column in "${column_names[@]}"; do
    check_name_validity "$column" 
    if [ ! "$?" -eq 0 ]; then
      print_error 12 "$column"
      return 12
    fi
  done

  return 0
}

# parameter 1: database name
# parameter 2: table name
# parameter 3: column_count
# parameter 4: column_names (array expanded)
# returns 11: if a column doesn't exsist
check_columns_existence(){
  # GET ARGUMENTS
  local idx=1
  local database_name="${!idx}" # $idx -> 1 . $1 -> argument
  ((idx++))
  local table_name="${!idx}"
  ((idx++))
  local column_count="${!idx}"
  ((idx++))
  declare -a column_names
  for((i=0; i<column_count; i++));do
    column_names+=("${!idx}")
    ((idx++))
  done
  local meta_table_path="${dbms_dir}/${database_name}/_${table_name}"


  for((i=0; i < column_count; i++)); do
    local column_name="${column_names[$i]}"
    local does_column_exist="false"
    does_column_exist=$(awk -F : -v column_name="${column_name}" ' 
    {
      if($1 == column_name){
        print "true"
      }
    }
    ' < "${meta_table_path}")
    if [[ "$does_column_exist" != "true" ]]; then
      print_error 11 "$column_name"
      return 11
    fi
  done
  return 0
}

# parameter 1: database name
# parameter 2: table name
# parameter 3: column_count
# parameter 4: column_names (array expanded)
# parameter 5: values_count 
# parameter 6: values (array expanded)
# returns 9 if data types don't match 
check_data_types(){
  # GET ARGUMENTS
  local idx=1
  local database_name="${!idx}" # $idx -> 1 . $1 -> argument
  ((idx++))
  local table_name="${!idx}"
  ((idx++))
  local column_count="${!idx}"
  ((idx++))
  declare -a column_names
  for((i=0; i<column_count; i++));do
    column_names+=("${!idx}")
    ((idx++))
  done
  local values_count="${!idx}"
  ((idx++))
  declare -a values
  for((i=0; i<values_count; i++));do
    values+=("${!idx}")
    ((idx++))
  done
  local meta_table_path="${dbms_dir}/${database_name}/_${table_name}"


  for((i=0; i < column_count; i++)); do
    local column_name="${column_names[$i]}"
    local value="${values[$i]}"
    local value_type
    local column_type

    if [[ "${value:0:1}" == "'" ]]; then
      value_type="varchar"
    else
      value_type="int"
    fi


    column_type=$(awk -F : -v column_name="${column_name}" ' 
    {
      if($1 == column_name){
        print $2
      }
    }
    ' < "${meta_table_path}")

    if [[ "${value_type}" != "${column_type}" ]]; then
      print_error 9
      return 9
    fi
  done

  return 0
}

# parameter 1: database name
# parameter 2: table name
# parameter 3: column_count
# parameter 4: column_names (array expanded)
# parameter 5: values_count 
# parameter 6: values (array expanded)
# returns 10 if primary key value already exists
check_primary_key(){
  # GET ARGUMENTS
  local idx=1
  local database_name="${!idx}" # $idx -> 1 . $1 -> argument
  ((idx++))
  local table_name="${!idx}"
  ((idx++))
  local column_count="${!idx}"
  ((idx++))
  declare -a column_names
  for((i=0; i<column_count; i++));do
    column_names+=("${!idx}")
    ((idx++))
  done
  local values_count="${!idx}"
  ((idx++))
  declare -a values
  for((i=0; i<values_count; i++));do
    values+=("${!idx}")
    ((idx++))
  done
  local meta_table_path="${dbms_dir}/${database_name}/_${table_name}"

  for((i=0; i < column_count; i++)); do
    local column_name="${column_names[$i]}"
    local value="${values[$i]}"
    local value_type
    local column_type

    primary_key_column_name=$(awk -F : ' 
    {
      if($3 == "primary key"){
        print $1
      }
    }
    ' < "${meta_table_path}")

    primary_key_column_field_number=$(awk -F : ' 
    {
      if($3 == "primary key"){
        print FNR
      }
    }
    ' < "${meta_table_path}")

    if [[ "${column_name}" == "${primary_key_column_name}" ]]; then
      # logic check that the value doesn't already exsist.
      local result
      result=$(awk -F : -v primary_key_column_field_number="$primary_key_column_field_number" -v value="$value" '
      BEGIN{
        current_value=0
      }
      {
        current_value = $primary_key_column_field_number
        if(value == current_value){
          print "already_exists"
        }
      }
      ' < "${dbms_dir}/${db_name}/${table_name}")

      if [[ "$result" == "already_exists" ]]; then
        print_error 10 "$column_name"
        return 10
      fi
    fi
  done

  return 0
}

