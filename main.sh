#! /usr/bin/bash

dbms_dir=".dbms"
if [ ! -d "$dbms_dir" ]; then
  mkdir "$dbms_dir"
fi

# a list of all databases created so far.
declare -a dbs
init () {
  PS3=">"
  LC_COLLATE=C
  shopt -s extglob
  # get already created dbs so far
  for db in "$dbms_dir"/*; do
    # Explanation: This is parameter expansion in bash ${parameter}
    # starting from the begining (#) delete all character (*) till you meet / (/) and keep
    # going if you meet any other successive / (the other #)
    # then append in the array where i keep track of all dbs so far.
    dbs+=(${db##*/})
  done
}


list_databases () {
  for ((i = 0; i < "${#dbs[@]}"; i++)); do
    echo "$((i+1)))" "${dbs[$i]}"
  done
}

connect_database () {
  true
}

drop_database () {
  select choice in "${dbs[@]}"; do
    if [ ! -d "${dbms_dir}/${choice}" ]; then
      echo "No databases matches the name $choice"
    else
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

show_main_window () {
  echo "==========================="
  echo "| ---------------------   |"
  echo "| |Select (1, 2, 3, 4)|   |"
  echo "| ---------------------   |"
  echo "| 1. List Databases       |"
  echo "| 2. Connect Database     |"
  echo "| 3. Create Database      |"
  echo "| 4. Drop Database        |"
  echo "| 5. Exit                 |"
  echo "==========================="
}


main () {
  init
  while true; do
    show_main_window
    read choice
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
      *)
        ;;
    esac
  done
}

main
