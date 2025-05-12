#! /usr/bin/bash
 
# Author: Mazen Fahim
# File: error.sh

source color.sh
# parameter 1: error code
# paramter 2: additional info to print in the error
print_error () {
  err="$1"
  info="$2"
  if [ $err -eq 0 ]; then
    echo -e "${RED}Err0x00: \"$info\" is not a valid command. type \"help\" for help${NC}"
  elif [ $err -eq 1 ]; then
    echo -e "${RED}Err0x01: Database name \"$info\" is invalid${NC}"
  elif [ $err -eq 2 ]; then
      echo -e "${RED}Err0x02: Database name \"$info\" already exists${NC}"
  elif [ $err -eq 3 ]; then
      echo -e "${RED}Err0x03: No databases matches the name \"$info\"${NC}"
  elif [ $err -eq 4 ]; then
      echo -e "${RED}Err0x04: Table name \"$info\" is invalid${NC}"
  elif [ $err -eq 5 ]; then
      echo -e "${RED}Err0x05: Table \"$info\" doesn't exist${NC}"
  elif [ $err -eq 6 ]; then
      echo -e "${RED}Err0x06: Table \"$info\" already exists${NC}"
  elif [ $err -eq 7 ]; then
      echo -e "${RED}Err0x07: Query syntax error. type \"help\" for help${NC}"
  elif [ $err -eq 8 ]; then
      echo -e "${RED}Err0x08: Number of columns doesn't equal number of values in insert query. type \"help\" for help${NC}"
  elif [ $err -eq 9 ]; then
      echo -e "${RED}Err0x09: Columns and values types don't match. type \"help\" for help${NC}"
  elif [ $err -eq 10 ]; then
      echo -e "${RED}Err0x10: Primary key value already exists for column \"$info\". type \"help\" for help${NC}"
  fi
}
