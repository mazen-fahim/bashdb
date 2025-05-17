#! /usr/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# parameter 1: choice to be validated
# parameter 2: lower bound (usually just 1 the first selection)
# parameter 3: upper bound
# returns 0 if within bounds
# returns 1 if outside of bounds
validate_input () {
  local choice
  local lower_bound
  local upper_bound
  choice="$1"
  lower_bound="$2"
  upper_bound="$3"

  if [ -n "${choice}" ] && [ "${choice}" -ge "$lower_bound" ] && [ "${choice}" -le "$upper_bound" ]; then
    return 0
  else
    echo "Err0x00: Invalid selection. Select $(seq -s ", " $lower_bound $upper_bound)."
    return 1
  fi
}



# parameter 1: the number of cols in the table
# parameter 2: the number of records in the table
# parameter 3: an array containg the table heading
# parameter 4: an associative array containg the table data
# TODO: Error check on parameters
# TODO: add table caption
# Ex: print_table 5 5 "ahmed fahim" b c d eas "$(declare -p arr)"
print_table () {
  # local term_cols
  local table_cols
  local table_rows
  local padding
  declare -a table_heading
  declare -a heading_lengths
  declare -a max_str_lengths # for each column get the max string in all of its rows
  # term_cols=$(tput cols)
  table_cols="$1"
  table_rows="$2"
  padding=1

  # TODO: what is eval?
  local offset=$((2+$1+1)) # p1, p2, c1, c2, c3, ..., cn, >array<
  # If there is no equal in the output of the command
  # $(decalare -p array) then the associative array
  # that was passed is actually empty!
  if [[ ! "${!offset#*=}" =~ = ]]; then
    eval declare -A table_data
  else
    eval "declare -A table_data="${!offset#*=}
  fi

  # initialize table heading array
  for ((i = 0, j = 3; i < table_cols; i++, j++)); do
    table_heading+=("${!j}") #! indirect expansion
  done


  # to detemine column width it's either gonna be one of two things
  # 1. the heading has length larger than the data below it
  # 2. the data below this heading has length larger than the heading itself
  # the width of the col will be the max between the two.
  for head in "${table_heading[@]}"; do heading_lengths+=("${#head}"); done

  for ((j = 0; j < table_cols; j++)); do
    local max_len=0
    for ((i = 0; i < table_rows; i++)); do
      local key="$i,$j"
      local val="${table_data[$key]}"
      local str_len=${#val}
        if [ $str_len -gt $max_len ]; then
          max_len=$str_len
        fi
    done
    max_str_lengths+=($max_len)
  done

  declare -a column_lengths
  for ((i = 0; i < table_cols; i++)); do
    local col_len=$((padding * 2)) # initialize with left right padding
    local head_len=${heading_lengths[$i]}
    local str_len=${max_str_lengths[$i]}
    if [ $head_len -gt $str_len ]; then
      ((col_len+=head_len))
    else
      ((col_len+=str_len))
    fi
    column_lengths+=($col_len)
  done

  #==========   PRINT THE TABLE HEADING   ==============================

  for ((i = 0; i < table_cols; i++));do
    local cell_len="${column_lengths[$i]}"
    local str="${table_heading[$i]}"
    local str_len="${#str}"
    local diff="$((cell_len - str_len))"
    local pad="$((diff / 2))"

    # 1. Padding before
    for((j = 0; j < pad; j++)); do echo -n " "; done
    ((cell_len-=pad))

    # 2. Data
    echo -n $str
    ((cell_len-=str_len))

    # 3. Padding after
    for((j = 0; j < cell_len; j++)); do echo -n " "; done
    echo -n "|"
  done
  printf "\n"

  # PRINT THE HEAD/RECORDS SPERATOR (------)
  for ((i = 0; i < table_cols; i++));do
    for ((j = 0; j < column_lengths[i]; j++));do
      echo -n "-"
    done
    echo -n '+'
  done
  printf "\n"

  #==========   PRINT THE TABLE DATA      ==============================

  # WHAT IF TABLE DATA IS EMPTY???
  
  
  
  # PRINT THE TABLE DATA
  for ((i=0; i < table_rows; i++)); do
    for ((j=0; j < table_cols; j++));do
      local cell_len=${column_lengths[$j]}
      local key="$i,$j"
      local str="${table_data[$key]}"
      local str_len=${#str}

      # 1. Padding before
      echo -n " "
      ((cell_len--))

      # 2. Data
      echo -n "${str}"
      ((cell_len-=str_len))

      # # 3. Padding after
      for((k = 0; k < cell_len; k++)); do echo -n " "; done
      echo -n "|" 

    done
    printf "\n"
  done

  echo "(${table_rows} rows)"


}

# parameter 1 : string to be trimmed
# returns the trimmed string
trim_string() {
    # Usage: trim_string "   example   string    "
    : "${1#"${1%%[![:space:]]*}"}"
    : "${_%"${_##*[![:space:]]}"}"
    printf '%s\n' "$_"
}


# parameter 1: the name to check
# returns 0: if the name is valid
# returns 1: if the name is invalid
# A special case where the column name is only * 
# this function returns successfully
check_name_validity() {
  reg_exp='^[a-zA-Z][a-zA-Z0-9_]*$'
  name="$1"

  # This is fine to be here since only the select
  # query syntax supports this as a column name
  # every other query will give a syntax error and would never
  # reach this point of checking the validity of column names
  if [[ "${name}" == '*' ]]; then
    return 0;
  fi

  if [[ "${name}" =~ $reg_exp ]]; then
    return 0
  else
    return 1
  fi
}

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

    if [[ -n "$accum" ]]; then
      accum="${accum%"${accum##*[![:space:]]}"}"
      accum="${accum#"${accum%%[![:space:]]*}"}"
      arr+=("$accum")
      accum=""
    fi

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

# parameter 1: An array of column names
# returns 0 if each column name is unique
# returns error code 17 if an any column name was repeated
# echos the first repeated element it detects 
check_repeated_column_name(){
  local arr=("$@")
  declare -A freq
  for elem in "${arr[@]}"; do
    if [[ -z "${freq[$elem]}" ]]; then
      freq["$elem"]=1
    else
      echo "$elem"
      return 17
    fi
  done
  return 0
}


tokenize_column_names_and_values() {
    str="$1"
    sz="${#str}"
    local -n arr=$2  

    inside_value="false"
    inside_quotes="false"
    accum=""

    for ((i=0; i<sz; i++)); do
        char="${str:$i:1}"

        # Handle comma separator
        if [[ "$char" == "," && "$inside_quotes" == "false" ]]; then
            # Trim whitespace and add to array
            accum="${accum%"${accum##*[![:space:]]}"}"
            accum="${accum#"${accum%%[![:space:]]*}"}"
            arr+=("$accum")
            accum=""
            inside_value="false"
            continue
        fi

        # Handle equals sign (only outside quotes)
        if [[ "$char" == "=" && "$inside_quotes" == "false" ]]; then
            # Trim and add the column name
            accum="${accum%"${accum##*[![:space:]]}"}"
            accum="${accum#"${accum%%[![:space:]]*}"}"
            arr+=("$accum")
            accum=""
            inside_value="true"  # Next part will be a value
            continue
        fi

        # Handle quotes
        if [[ "$char" == "'" ]]; then
            inside_quotes=$([[ "$inside_quotes" == "true" ]] && echo "false" || echo "true")
            accum+="$char"
            continue
        fi

        # Skip formatting characters when not in a value
        if [[ "$inside_value" == "false" && "$inside_quotes" == "false" ]]; then
            if [[ "$char" == " " || "$char" == "(" || "$char" == ")" ]]; then
                continue
            fi
        fi

        # Add character to accumulator
        accum+="$char"
    done

    # Add the last accumulated value if exists
    if [[ -n "$accum" ]]; then
        accum="${accum%)}" 
        accum="${accum%"${accum##*[![:space:]]}"}"  
        accum="${accum#"${accum%%[![:space:]]*}"}"  
        arr+=("$accum")
    fi

  #this will print an array of the column names and values
  # c1 5 c2 're'
}


extract_column_names() {
    local -n source_arr=$1  
    local -n dest_arr=$2    
    
    # Clear destination array
    dest_arr=()
    
    # Column names are every even-indexed element (0, 2, 4...)
    for ((i=0; i<${#source_arr[@]}; i+=2)); do
        dest_arr+=("${source_arr[i]}")
    done
}

# Validation function matching your preferred style
check_columns_name_validity() {
    local count=$1
    shift
    local invalid=0

    for ((i=1; i<=$count; i++)); do
        col_name="${!i}"
        if [[ ! "$col_name" =~ $name_pattern ]] then
            echo "Invalid column name: '$col_name'"
            invalid=1
        fi
    done

    return $invalid
}

extract_column_value() {
    local -n source_arr=$1  
    local -n dest_arr=$2    
    
    # Clear destination array
    dest_arr=()
    
    # Column values are every odd-indexed element (1, 3, 5...)
    for ((i=1; i<${#source_arr[@]}; i+=2)); do
        dest_arr+=("${source_arr[i]}")
    done
}

check_columns_values_validity() {
    local count=$1
    shift
    local invalid=0

    for ((i=1; i<=$count; i++)); do
        col_value="${!i}"
        if [[ ! "$col_value" =~ $value_pattern ]] then
            echo "Invalid column value: '$col_value'"
            invalid=1
        fi
    done

    return $invalid
}
