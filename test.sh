#! /usr/bin/bash

# run () {
#   arr=("$@") # "$@" this expands to all arguments each one quoted.
#   for i in "${arr[@]}"; do
#     echo "$i"
#   done
# }
#
#
# run 1 2 3



declare -A arr=(
  ["0,0"]="v" 
  ["1,0"]="v" 
  ["2,0"]="v" 
  ["3,0"]="v" 
  ["4,0"]="v" 
  ["5,0"]="v"

  ["0,1"]="v1" 
  ["1,1"]="v11" 
  ["2,1"]="v123" 
  ["3,1"]="v10" 
  ["4,1"]="v11" 
  ["5,1"]="v1"

  ["0,2"]="v1" 
  ["1,2"]="v11" 
  ["2,2"]="v123" 
  ["3,2"]="v10" 
  ["4,2"]="v11" 
  ["5,2"]="v1"

  ["0,3"]="v1" 
  ["1,3"]="v11" 
  ["2,3"]="v123" 
  ["3,3"]="v10" 
  ["4,3"]="v11" 
  ["5,3"]="v1"

  ["0,4"]="v111111111111111" 
  ["1,4"]="v11" 
  ["2,4"]="v123" 
  ["3,4"]="v10" 
  ["4,4"]="v11" 
  ["5,4"]="v1"
)

# parameter 1: the number of cols in the table
# parameter 2: the number of records in the table
# parameter 3: an array containg the table heading
# parameter 4: an associative array containg the table data
print_table () {
  local term_cols
  local table_cols
  local table_rows
  local padding
  declare -a table_heading
  declare -a heading_length
  declare -a max_data_length
  term_cols=$(tput cols)
  table_cols="$1"
  table_rows="$2"
  padding=1

  # TODO: what is eval?
  local offset=$((2+$1+1)) # p1, p2, c1, c2, c3, ..., cn, >array<
  eval "declare -A table_data="${!offset#*=}

  # initialize table heading array
  for ((i = 0, j = 3; i < table_cols; i++, j++)); do
    table_heading+=(${!j}) #! indirect expansion
  done


  # to detemine column width it's either gonna be one of two things
  # 1. the heading has length larger than the data below it
  # 2. the data below this heading has length larger than the heading itself
  # the width of the col will be the max between the two.
  for head in "${table_heading[@]}"; do
    heading_length+=("${#head}")
    done

    for ((j = 0; j < table_cols; j++)); do
      local max_length=0
      for ((i = 0; i < table_rows; i++)); do
        local key="$i,$j"
        local val="${table_data[$key]}"
        local col_length=${#val}
          if [ $col_length -gt $max_length ]; then
            max_length=$col_length
          fi
        done
        max_data_length+=($max_length)
      done

      declare -a column_lengths
      for ((i = 0; i < table_cols; i++)); do
        local col_length=$((padding * 2)) # left right padding
        local head_length=${heading_length[$i]}
        local data_length=${max_data_length[$i]}
        if [ $heading_length -gt $data_length ]; then
          ((col_length+=heading_length))
        else
          ((col_length+=data_length))
        fi
        column_lengths+=($col_length)
      done


      # PRINT THE TABLE HEADING
      for ((i = 0; i < table_cols; i++));do
        local col_len=${column_lengths[$i]}
        local str_len=${#table_heading[$i]}
        local pad=$(((col_len - str_len) / 2))
        for((j = 0; j < pad; j++)); do
          echo -n " "
        done
        echo -n "${table_heading[$i]}"
        for((j = 0; j < pad; j++)); do
          echo -n " "
        done
        if [ $((pad%2)) -eq 1 ]; then echo -n " "; fi
        echo -n " " # to account for the + seperator between fields
      done
      printf "\n"
      for ((i = 0; i < table_cols; i++));do
        for ((j = 0; j < column_lengths[i]; j++));do
          echo -n "-"
        done
        echo -n '+'
      done
      printf "\n"


      echo "Table columns: $table_cols"
      echo "Table heading: ${table_heading[@]}"
      echo "Table heading lengths: ${heading_length[@]}"
      echo "Table data max lengths: ${max_data_length[@]}"
      echo "Table col lengths: ${column_lengths[@]}"


    }

print_table 5 5 a b c d eas "$(declare -p arr)"
