#! /usr/bin/bash
source utils.sh

# parameter 1: database name
list_tables () {
  db_name="$1"

  declare -a headings=("Table Name" "Records Count")
  declare -A tb

  row=0
  for tb in "$dbms_dir"/"$db_name"/*; do
    if [[ -f $tb ]]; then
      local tb_name=$(sed -n "s+${dbms_dir}/${db_name}/++gp" <<< $tb)
      # local tb_name=${tb##*/}
      # make sure that it's not the meta file
      if [[ "$tb_name" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        tb["$row,0"]="$tb_name"
        tb["$row,1"]="$(cat "$dbms_dir"/"$db_name"/"$tb_name" | wc -l)"
        ((row++))
      fi
    fi
  done
  print_table "${#headings[@]}" "${row}" "${headings[@]}" "$(declare -p tb)"

  echo ""
}

# parameter 1: connected database name
# parameter 2: table name to drop
# returns 4 if database name is not valid
# returns 5 if table doesn't exisits
drop_table() {
  db_name="${1}"
  tb_name="${2}"
  check_name_validity "${tb_name}"
  if [ "$?" -eq 0 ]; then
    if [ -f "${dbms_dir}/${db_name}/${tb_name}" ]; then
      rm "${dbms_dir}/${db_name}/${tb_name}"
      rm "${dbms_dir}/${db_name}/_${tb_name}"
      sleep 1
      echo -e "${GREEN}Removed table ${tb_name}${NC}"
    else
      print_error 5 "${tb_name}"
      return 5
    fi
  else
      print_error 4 "${tb_name}"
      return 4
  fi
  echo ""
}

# parameter 1: connected database name
# parameter 2: sql create query
# returns 4 if table name is not valid
# returns 6 if table already exisits
create_table() {
  db_name="${1}"
  query="${2}"
# ^create\s+table\s+([a-zA-Z]\w*)\s*\(
# /(\s*([a-zA-Z]\w*)\s+(int|varchar)(\s+primary key)?\s*(,|\)$))/gm
  create_regexp='^create\s+table\s+([a-zA-Z]\w*)\s*\('
  create_content_regexp='(\s*([a-zA-Z]\w*)\s+(int|varchar)(\s+primary key)?\s*(,|\)$))'

  if [[ "$query" =~ $create_regexp ]]; then
    query_content="${query#*\(}"
    tb_name="${BASH_REMATCH[1]}"

    declare -a matches
    while true; do
      if [[ "$query_content" =~ $create_content_regexp ]]; then
        matches+=("${BASH_REMATCH[@]}")
        # delete each matched string to run the next match.
        query_content=$(sed -n -r "s/${create_content_regexp}//p" <<< $query_content)
      else
        break
      fi
    done
    if [ -z "$query_content" ]; then
      sz="${#matches[@]}"
      for((i = 0; i < sz; i++)); do
        echo $i: "${matches[$i]}"
      done
    else
      print_error 7
      return 7
    fi

  else
    print_error 7
    return 7
  fi

  # check_name_validity "${tb_name}"
  # if [ "$?" -eq 0 ]; then
  #   if [ ! -f "${dbms_dir}/${db_name}/${tb_name}" ]; then
  #
  #     touch "${dbms_dir}/${db_name}/${tb_name}"
  #     touch "${dbms_dir}/${db_name}/_${tb_name}"
  #     sleep 1
  #     echo -e "${GREEN}Created table\"$tb_name\"${NC}"
  #   else
  #     print_error 6 "${tb_name}"
  #     return 6
  #   fi
  # else
  #   print_error 4 "${tb_name}"
  #   return 4
  # fi
  # echo ""
}



# TODO: 
# 1. CREATE
# - types: int, varchar (any column that's not a primary key can be null)
# - constraints: primary key
# ^create\s+table\s+([a-zA-Z]\w*)\s*\(
# /(\s*([a-zA-Z]\w*)\s+(int|varchar)(\s+primary key)?\s*(,|\)$))/gm
#
# create table table_name (id int primary key, name varchar(20) not null);
# create\s+table\s+(?<table_name>[a-zA-Z][a-zA-Z0-9_]*)\s*\((\s*([a-zA-Z][a-zA-Z0-9_]*)\s+([a-zA-Z][a-zA-Z0-9_()]*)\s+(primary key|no null)?[,')']?)+

#1. create\s+table\s+\w+\s*\(([^)]+)\)
#2. \s*([a-zA-Z][a-zA-Z0-9_]*)\s+([a-zA-Z][a-zA-Z0-9_()]*)\s+(primary key|no null)?\s*[,)]?

# insert 
# select 
# delete 
# update

