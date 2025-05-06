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
      local tb_name=${tb##*/}
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
# parameter 2: table name to create
# returns 4 if table name is not valid
# returns 6 if table already exisits
create_table() {
  db_name="${1}"
  tb_name="${2}"
  check_name_validity "${tb_name}"
  if [ "$?" -eq 0 ]; then
    if [ ! -f "${dbms_dir}/${db_name}/${tb_name}" ]; then
      touch "${dbms_dir}/${db_name}/${tb_name}"
      touch "${dbms_dir}/${db_name}/_${tb_name}"
      sleep 1
      echo -e "${GREEN}Created table\"$tb_name\"${NC}"
    else
      print_error 6 "${tb_name}"
      return 6
    fi
  else
    print_error 4 "${tb_name}"
    return 4
  fi
  echo ""
}



