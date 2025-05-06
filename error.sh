#! /usr/bin/bash
source color.sh
# parameter 1: error code
print_error () {
  err="$1"
  command="$2"
  db_name="$2"
  if [ $err -eq 0 ]; then
    echo -e "bashdb@# > ${RED}Err0x00: \"$command\" is not a valid command. type \"help\" for help${NC}"
  elif [ $err -eq 1 ]; then
    echo -e "${RED}Err0x01: Database name \"$db_name\" is invalid${NC}"
  elif [ $err -eq 2 ]; then
      echo -e "${RED}Err0x02: Database name \"$db_name\" already exists${NC}"
  elif [ $err -eq 3 ]; then
      echo -e "${RED}Err0x03: No databases matches the name \"$db_name\"${NC}"
  fi
}
