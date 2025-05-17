#! /usr/bin/bash

# Author: Mazen Fahim
# File: main.sh

#include other files
# i run them as souce because i want their return values $? to be seen in
# here the main script
source utils.sh
source color.sh
source error.sh

source create_query.sh
source insert_query.sh
source delete_query.sh
source update_query.sh
source select_query.sh
source drop_query.sh
source list_tables.sh

# a global list of all databases created so far.
LC_COLLATE=C
shopt -s extglob

# Global state 
dbms_dir="$(dirname ${BASH_SOURCE[0]})/.dbms"
# declare -a dbs

init () {
  # Create the root dir for the database
  if [ ! -d "$dbms_dir" ]; then
    mkdir "$dbms_dir"
    mkdir "$dbms_dir"/main
  fi
}

# parameter 1: index of element to remove.
# parameter 2,3,N: the array elements
remove_elem_from_arr () {
  local arr
  for ((i = 0; i < $#; i++)); do
    true
  done
  arr=("$@")

}



list_databases () {
  declare -a headings=("Database Name" "Table Count")
  declare -A table
  row=0
  for db in "$dbms_dir"/*; do
    if [[ ! -d "$db" ]]; then continue; fi
    local db_name=$(sed -n "s+${dbms_dir}/++gp" <<< $db)
    # local db_name="${db##*/}"

    # table["$row,0"]=$((row+1)) # numbers used to list the present databases
    table["$row,0"]="$db_name" # the name of the data base
    table["$row,1"]=$(($(ls -1 ${dbms_dir}/${db_name} | wc -l) / 2)) # number of tables inside the database

    ((row++))
  done

  print_table "${#headings[@]}" "$((row))" "${headings[@]}" "$(declare -p table)"
  echo ""
}

# parameter 1: database name to connect to
connect () {
  db_name="$1"
  while true; do
    read -e -p "bashdb@${db_name} > " input
    input="${input,,}"
    if [[ "$input" =~ ^create* ]]; then
      handle_create_query "${db_name}" "$input"
    elif [[ "$input" =~ ^insert* ]]; then
      handle_insert_query "${db_name}" "$input"
    elif [[ "$input" =~ ^update* ]]; then
      handel_update_query "${db_name}" "$input"
    elif [[ "$input" =~ ^drop* ]]; then
      handle_drop_query "${db_name}" "$input"
    elif [[ "$input" =~ ^delete* ]]; then
      handle_delete_query "${db_name}" "$input"
    elif [[ "$input" =~ ^select* ]]; then
      handle_select_query "${db_name}" "$input"
    elif [[ "${input}" =~ ^connect* ]]; then
      print_error 15 "$db_name"

    elif [[ "${input}" =~ ^ls$ ]]; then
      list_tables "${db_name}"
    elif [[ "${input}" =~ ^help$ ]]; then
      show_help
    elif [[ "${input}" =~ ^clear$ ]]; then
      clear
      echo "bashdb v1.0"
      echo "Type \"help\" for help"
      echo ""
    elif [[ "${input}" =~ ^exit$ ]]; then
      echo -e "${GREEN}Exited from database \"${db_name}\"${NC}"
      echo ""
      return 0
    else
      print_error "0" "${input}"
    fi

  done
}


# TODO: Connect database by number
# parameter 1: name of the database to be connected
# returns 1 if database name is not valid
# returns 3 if database doesn't exisits
connect_database () {
  db_name="$1"
  check_name_validity "${db_name}"
  if [ "$?" -eq 0 ]; then
    if [ -d "${dbms_dir}/${db_name}" ]; then
      echo -e "${GREEN}Connected to database \"${db_name}\"${NC}"
      echo ""
      connect "${db_name}"
    else
      print_error 3 "${db_name}"
      return 3
    fi
  else
    print_error 1 "${db_name}"
    return 1
  fi
  echo ""
}


# TODO: Drop database by number
# parameter 1: name of the database to be droped
# returns 1 if database name is not valid
# returns 3 if database doesn't exisits
drop_database () {
  db_name="$1"
  check_name_validity "${db_name}"
  if [ "$?" -eq 0 ]; then
    if [ -d "${dbms_dir}/${db_name}" ]; then
      rm -rf "${dbms_dir}/${db_name}"
      echo -e "${GREEN}Removed database ${db_name}${NC}"
    else
      print_error 3 "${db_name}"
      return 3
    fi
  else
      print_error 1 "${db_name}"
      return 1
  fi
  echo ""
}


# parameter 1: name of the database to be created
# returns 1 if database name is not valid
# returns 2 if database already exisits
create_database () {
  db_name="$1"
  check_name_validity "${db_name}"
  if [ "$?" -eq 0 ]; then
    if [ ! -d "${dbms_dir}/${db_name}" ]; then
      mkdir "${dbms_dir}/${db_name}"
      echo -e "${GREEN}Created database \"$db_name\"${NC}"
    else
      print_error 2 "${db_name}"
      return 2
    fi
  else
    print_error 1 "${db_name}"
    return 1
  fi
  echo ""
}


# shows the help manual
show_help () {
  echo "bashdb is a database engine written in bash. I regret doing this :("
  echo "When you first start bashdb you have a main database"
  echo ""
  echo "Commands"
  printf "  %-20s%s\n" "help" "Shows this help" 
  printf "  %-20s%s\n" "ls" "If not connected to any database, lists all existing databases" 
  printf "  %-20s%s\n" " " "If connected to a database, lists all tables inside the database"
  printf "  %-20s%s\n" "connect NAME" "If not connected to a database, connects to the database" 
  printf "  %-20s%s\n" " " "If connected to a database, results in an error (you are already connected)" 
  printf "  %-20s%s\n" "create NAME" "If not connected to a database, creates a new database" 
  printf "  %-20s%s\n" " " "If connected to a database, creates a new table inside the database"
  printf "  %-20s%s\n" "drop NAME" "If not connected to a database, deletes the database" 
  printf "  %-20s%s\n" " " "If connected to a database, deletes the table inside the database"
  printf "  %-20s%s\n" "clear" "clear the terminal" 
  printf "  %-20s%s\n" "exit" "If not connected to any database, exits from bashdb" 
  printf "  %-20s%s\n" " " "If connected to a database, exits from the database" 
  echo ""
  echo "Prompt"
  printf "  %-20s%s\n" "\"bashdb@# >\"" "# means you are currently not connected to any database" 
  printf "  %-20s%s\n" "\"bashdb@NAME >\"" "NAME is the name of the databases you are currently connected to." 
  echo ""
}


run () {
  echo "bashdb v1.0"
  echo "Type \"help\" for help"
  echo ""

  local connect_command_pattern="^connect\s+([a-zA-Z][a-zA-Z0-9_ ]*)"
  local drop_command_pattern="^drop\s+([a-zA-Z][a-zA-Z0-9_ ]*)"
  local create_command_pattern="^create\s+([a-zA-Z][a-zA-Z0-9_ ]*)"

  while true; do
    read -e -p "bashdb@# > " input
    input="${input,,}"
    if [[ "${input}" =~ ^help$ ]]; then
      show_help
    elif [[ "${input}" =~ ^ls$ ]]; then
      list_databases
    elif [[ "${input}" =~  $connect_command_pattern ]]; then
      local database_name="${BASH_REMATCH[1]}"
      connect_database "$database_name"
    elif [[ "${input}" =~ $create_command_pattern ]]; then
      local database_name="${BASH_REMATCH[1]}"
      create_database "$database_name"
    elif [[ "${input}" =~ $drop_command_pattern ]]; then
      local database_name="${BASH_REMATCH[1]}"
      drop_database "$database_name"
    elif [[ "${input}" == "clear" ]]; then
      clear
      echo "bashdb v1.0"
      echo "Type \"help\" for help"
      echo ""
    elif [[ "${input}" == "exit" ]]; then
      exit 0
    else
      print_error "0" "${input}"
    fi
  done
}

main () {
  init
  run
}

main
