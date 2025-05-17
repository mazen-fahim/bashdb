#! /usr/bin/bash
source utils.sh

# parameter 1: database name
list_tables () {
  local database_name="$1"

  declare -a headings=("Table Name" "Records Count")
  declare -A tb

  row=0
  for tb in "$dbms_dir"/"$database_name"/*; do
    if [[ -f $tb ]]; then
      local tb_name=$(sed -n "s+${dbms_dir}/${database_name}/++gp" <<< $tb)
      # local tb_name=${tb##*/}
      # make sure that it's not the meta file
      if [[ "$tb_name" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        tb["$row,0"]="$tb_name"
        tb["$row,1"]="$(($(cat "$dbms_dir"/"$database_name"/"$tb_name" | wc -l) - 1))"
        ((row++))
      fi
    fi
  done
  print_table "${#headings[@]}" "${row}" "${headings[@]}" "$(declare -p tb)"

  echo ""
}
