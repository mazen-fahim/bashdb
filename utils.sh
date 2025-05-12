#! /usr/bin/bash

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


