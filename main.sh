#! /usr/bin/bash

#include other files
# i run them as souce because i want their return values $? to be seen in
# here the main script
source utils.sh
source color.sh
source error.sh

# a global list of all databases created so far.
LC_COLLATE=C
shopt -s extglob

# Global state 
dbms_dir='./.dbms'
# declare -a dbs

init () {
  # Create the root dir for the database
  if [ ! -d "$dbms_dir" ]; then
    mkdir "$dbms_dir"
  fi

  # # Init already created dbs so far
  # for db in ./"$dbms_dir"/*; do
  #   # Explanation: This is "parameter expansion" in bash ${parameter}
  #   # starting from the begining (#) delete all character (*) till you meet / (/) and keep
  #   # going if you meet any other successive / (the other #)
  #   # then append in the array where i keep track of all dbs so far.
  #   dbs+=(${db##*/}) # /path/to/file -> file
  # done
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


# parameter 1: the name to check
# returns 0: if the name is valid
# returns 1: if the name is invalid
check_name_validity() {
  reg_exp='^[a-zA-Z][a-zA-Z0-9_]*$'
  name="$1"
  if [[ "$name" =~ $reg_exp ]]; then
    return 0
  else
    return 1
  fi
}

list_databases () {
  declare -a headings=("#" "Name" "Table Count")
  declare -A table
  row=0
  for db in "$dbms_dir"/*; do
    local db_name=${db##*/}
    declare -a tables=($(ls "$dbms_dir"/"$db_name"))

    table["$row,0"]=$((row+1)) # numbers used to list the present databases
    table["$row,1"]="$db_name" # the name of the data base
    table["$row,2"]="${#tables[@]}" # number of tables inside the database

    ((row++))
  done

  print_table "${#headings[@]}" "$((row))" "${headings[@]}" "$(declare -p table)"
  echo ""
}

# parameter 1: database name to connect to
connect () {

  true
}

# TODO: Connect database by number
connect_database () {
  list_databases
  read -p "connect > Database Name: " db_name
  check_name_validity "$db_name"
  if [ "$?" -eq 0 ]; then
    if [ -d "${dbms_dir}/${db_name}" ]; then
      # CONNECT TO THE DATABASE
      connect $db_name
    else
      print_error 3 "$db_name"
    fi
  else
    print_error 1 "$db_name"
  fi
  echo ""
}

# TODO: Drop database by number
drop_database () {
  db_name="$1"
  check_name_validity "$db_name"
  if [ "$?" -eq 0 ]; then
    if [ -d "${dbms_dir}/${db_name}" ]; then
      rm -rf "${dbms_dir}/${db_name}"
      sleep 1
      echo -e "${GREEN}Removed database ${db_name}${NC}"
    else
      print_error 3 "$db_name"
    fi
  else
      print_error 1 "$db_name"
  fi
  echo ""
}



create_database () {
  db_name="$1"
  check_name_validity "$db_name"
  if [ "$?" -eq 0 ]; then
    if [ ! -d "${dbms_dir}/${db_name}" ]; then
      mkdir "${dbms_dir}/${db_name}"
      sleep 1
      echo -e "${GREEN}Created database \"$db_name\"${NC}"
    else
      print_error 2 "$db_name"
    fi
  else
    print_error 1 "$db_name"
  fi
  echo ""
}


# shows the help manual
show_help () {
  echo "bashdb is a small database engine written in bash. I regret doing this :("
  echo ""
  echo "Commands"
  printf "  %-20s%s\n" "help" "Shows this help" 
  printf "  %-20s%s\n" "ls" "If not connected to any database, lists all existing databases." 
  printf "  %-20s%s\n" " " "If connected to a database, lists all tables inside the database"
  printf "  %-20s%s\n" "connect NAME" "connect to a database" 
  printf "  %-20s%s\n" "create NAME" "create a new database" 
  printf "  %-20s%s\n" "drop NAME" "delete a database" 
  printf "  %-20s%s\n" "clear" "clear the terminal" 
  printf "  %-20s%s\n" "exit" "exit from bashdb" 
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
  while true; do
    read -p "bashdb@# > " command argument
    if [[ "$command" == "help" ]]; then
      show_help
    elif [[ "$command" == "ls" ]]; then
      list_databases
    elif [[ "$command" == "connect" ]]; then
      connect_database "$argument"
    elif [[ "$command" == "create" ]]; then
      create_database "$argument"
    elif [[ "$command" == "drop" ]]; then
      drop_database "$argument"
    elif [[ "$command" == "clear" ]]; then
      clear
    elif [[ "$command" == "exit" ]]; then
      exit 0
    else
      print_error "0" "$command"
    fi

  done
}

main () {
  init
  run
}

main
