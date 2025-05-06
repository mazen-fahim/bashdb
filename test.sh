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
  ["2,2"]="v12" 
  ["3,2"]="v10" 
  ["4,2"]="v1asdjf;asjals;jdf;jfsadl;jl;asfjd;ljfasdk;j;lkafjds;ljasd;lfj;kladsfj;sajfdfsadk;lj;kalsdjd1" 
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
  eval "declare -A table_data="${!offset#*=}

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

      echo "Table columns: $table_cols"
      echo "Table heading: ${table_heading[@]}"
      echo "heading_lengths: ${heading_lengths[@]}"
      echo "max_str_lengths: ${max_str_lengths[@]}"
      echo "Table col lengths: ${column_lengths[@]}"
      echo ""
      echo ""
      echo ""

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
      echo -n "$str"
      ((cell_len-=str_len))

      # # 3. Padding after
      for((k = 0; k < cell_len; k++)); do echo -n " "; done
      echo -n "|" 

    done
    printf "\n"
  done
}

print_table 5 5 "ahmed fahim" b c d eas "$(declare -p arr)"
