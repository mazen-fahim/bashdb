#! /usr/bin/bash
 
# Author: Mazen Fahim
# File: error.sh

# parameter 1: error code
# paramter 2: additional info to print in the error
print_error () {
  err="$1"
  info="$2"
  if [ $err -eq 0 ]; then
    
    echo -e "${RED}Err0x00: \"$info\" is not a valid command. type \"help\" for help${NC}"
    echo ""
  elif [ $err -eq 1 ]; then
    
    echo -e "${RED}Err0x01: Database name \"$info\" is invalid${NC}"
    echo ""
  elif [ $err -eq 2 ]; then
      
      echo -e "${RED}Err0x02: Database name \"$info\" already exists${NC}"
      echo ""
  elif [ $err -eq 3 ]; then
      
      echo -e "${RED}Err0x03: No databases matches the name \"$info\"${NC}"
      echo ""
  elif [ $err -eq 4 ]; then
      
      echo -e "${RED}Err0x04: Table name \"$info\" is invalid${NC}"
      echo ""
  elif [ $err -eq 5 ]; then
      
      echo -e "${RED}Err0x05: Table \"$info\" doesn't exist${NC}"
      echo ""
  elif [ $err -eq 6 ]; then
      
      echo -e "${RED}Err0x06: Table \"$info\" already exists${NC}"
      echo ""
  elif [ $err -eq 7 ]; then
      
      echo -e "${RED}Err0x07: Query syntax error. type \"help\" for help${NC}"
      echo ""
  elif [ $err -eq 8 ]; then
      
      echo -e "${RED}Err0x08: Number of columns doesn't equal number of values in insert query. type \"help\" for help${NC}"
      echo ""
  elif [ $err -eq 9 ]; then
      
      echo -e "${RED}Err0x09: Columns and values types don't match. type \"help\" for help${NC}"
      echo ""
  elif [ $err -eq 10 ]; then
      
      echo -e "${RED}Err0x10: Primary key value already exists for column \"$info\". type \"help\" for help${NC}"
      echo ""
  elif [ $err -eq 11 ]; then
      
      echo -e "${RED}Err0x11: Column \"$info\" doesn't exist. type \"help\" for help${NC}"
      echo ""
  elif [ $err -eq 12 ]; then
      
      echo -e "${RED}Err0x12: Column \"$info\" name is invalid. type \"help\" for help${NC}"
      echo ""
  elif [ $err -eq 13 ]; then
      
      echo -e "${RED}Err0x13: You can't have "*" with other column names in select query. type \"help\" for help${NC}"
      echo ""
  elif [ $err -eq 14 ]; then
      
      echo -e "${RED}Err0x14: You can't use logical operator \"$info\" with type varchar. You can only use "=" and "!=". type \"help\" for help${NC}"
      echo ""
  elif [ $err -eq 15 ]; then
      
      echo -e "${RED}Err0x15: You are already connected to database \"$info\". Exit first if you want to connect to another one.type \"help\" for help${NC}"
      echo ""
  elif [ $err -eq 16 ]; then
      
      echo -e "${RED}Err0x16: You can't have multiple primary keys in the same table. Type \"help\" for help${NC}"
      echo ""
  elif [ $err -eq 17 ]; then
      
      echo -e "${RED}Err0x17: You can't have multiple columns with the same name \"$info\". Type \"help\" for help${NC}"
      echo ""
  elif [ $err -eq 18 ]; then
      
      echo -e "${RED}Err0x18: You can't update the primary key column \"$info\" for multiple records with the same value. Type \"help\" for help${NC}"
      echo ""
  fi

  return 0
}
