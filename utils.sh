#! /usr/bin/bash

# parameter 1: choice to be validated
# parameter 2: lower bound (usually just 1 the first selection)
# parameter 3: upper bound
# returns 0 if within bounds
# returns 1 if outside of bounds
validate_input () {
  local choice
  local lower_bound
  local upper_bound
  choice="$1"
  lower_bound="$2"
  upper_bound="$3"

  if [ -n "$choice" ] && [ "$choice" -ge "$lower_bound" ] && [ "$choice" -le "$upper_bound" ]; then
    return 0
  else
    echo "Err0x00: Invalid selection. Select $(seq -s ", " $lower_bound $upper_bound)."
    return 1
  fi
}


