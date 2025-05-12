#! /usr/bin/bash

# parameter 1: the string we want to tokenize something
#               like this  "(  ' hii  hi' , 123 , 'val'  )"
# parameter 2: an empty array to be populated by the
#              output of this function
# returns an array containg the values
tokenize_insert_values(){
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

# parameter 1: database name
# parameter 2: table name
# parameter 3: column_count
# parameter 4: column_names (array expanded)
# parameter 5: values_count 
# parameter 6: values (array expanded)
# returns 8: if column_count != values_count
check_data_types() {
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

  if [[ "$column_count" != "$values_count" ]]; then
    print_error 8
    return 8
  fi

  # Check Data Types
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

    local meta_table_path="${dbms_dir}/${database_name}/_${table_name}"

    column_type=$(awk -F : -v column_name="${column_name}" ' 
    {
      if($1 == column_name){
        print $2
      }
    }
    ' < "${meta_table_path}")

    # echo "Column Number:" "$((i+1))"
    # echo "Column Name:" "${column_name}"
    # echo "Value:" "${value}"
    # echo "Value Type Deduced:" "${value_type}"
    # echo "Column Type From Meta Table:" "${column_type}"
    if [[ "${value_type}" != "${column_type}" ]]; then
      print_error 9
      return 9
    fi

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
      echo "EL COLUMN PTA3 EL PRIMARY KEY MWGOOD FE EL 5ANA RKM $primary_key_column_field_number"
      echo "WE EL KEMA ELY 3AYZ A7OTHA FEH = $value"
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
      echo "ANA EL RESULE= $result"

      if [[ "$result" == "already_exists" ]]; then
        print_error 10 "$column_name"
        return 10
      fi
    fi

  done

  return 0

}
