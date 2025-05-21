#! /usr/bin/bash

source utils.sh

# parameter 1: connected database name
# parameter 2: table name to drop
# returns 4 if table name is not valid
# returns 5 if table doesn't exisits
handle_drop_query() {
  local database_name="${1}"
  local query="${2,,}"
  local table_name

  #                       -------------------------
  # 1. will match this -> |drop table   table_name|
  #                       -------------------------
  local drop_table_pattern="^drop\s+table\s+($name_pattern)"


  if [[ "$query" =~ $drop_table_pattern ]]; then
    table_name="$(remove_leading_trailing_whitespaces "${BASH_REMATCH[1]}")"

    check_name_validity "$table_name"
    if [[ ! $? -eq 0 ]]; then
      print_error 4 "$table_name"
      return 4
    fi

    if [ -f "${dbms_dir}/${database_name}/${table_name}" ]; then
      rm "${dbms_dir}/${database_name}/${table_name}"
      rm "${dbms_dir}/${database_name}/_${table_name}"
      echo -e "${GREEN}Table \"${table_name}\" is dropped.${NC}"
      echo ""
    else
      print_error 5 "${table_name}"
      return 5
    fi
  else
    print_error 7
  fi
}
