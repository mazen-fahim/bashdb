#! /usr/bin/bash

#include other files
# i run them as souce because i want their return values $? to be seen in
# here the main script
source utils.sh

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


list_databases () {
  declare -a headings=("#" "Name")
  declare -A table
  row=0
  for db in "$dbms_dir"/*; do
    db_name=${db##*/}

    table["$row,0"]=$((row+1)) # numbers used to list the present databases
    table["$row,1"]="$db_name" # the name of the data base
    table["$row,2"]="0" # number of tables inside the database

    ((row++))
  done
  print_table 3 $((row)) "#" "Name" "Table Count" "$(declare -p table)"
  # echo dbbss$databases
  # for ((i = 0; i < ${#dbs[@]}; i++)); do
  #   echo "$((i+1))." "${dbs[$i]}"
  # done
}

connect_database () {
  true
}

drop_database () {
  select choice in "${dbs[@]}"; do
    if [ ! -d "${dbms_dir}/${choice}" ]; then
      echo "Err0x01: No databases matches the name $choice."
    else
      echo "Removed database $choice"
      rm -rf "${dbms_dir}/${choice}"
    fi
  done
}



create_database () {
  read -p "Database Name: " db_name 
  # TODO: CHECK NAME IS CORRECT (Starts with alphapets only )
  mkdir "${dbms_dir}/${db_name}"
  dbs+=($db_name)
}


run () {
  while true; do
    echo "==========================="
    echo "| 1. List Databases       |"
    echo "| 2. Connect Database     |"
    echo "| 3. Create Database      |"
    echo "| 4. Drop Database        |"
    echo "| 5. Exit                 |"
    echo "==========================="
    read -p "select > " choice
    validate_input $choice 1 5
    if [ "$?" -eq 0 ]; then
      case "$choice" in
        "1")
          list_databases
          ;;
        "2")
          ;;
        "3")
          create_database
          ;;
        "4")
          drop_database
          ;;
        "5")
          exit 0
          ;;
        *)
          ;;
      esac
    fi
  done
}

main () {
  init
  run
}

main

