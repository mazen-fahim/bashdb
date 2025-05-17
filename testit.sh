#! /usr/bin/bash
tokenize_column_names_and_values() {
    str="$1"
    sz="${#str}"
    local -n arr=$2  

    inside_value="false"
    inside_quotes="false"
    accum=""

    for ((i=0; i<sz; i++)); do
        char="${str:$i:1}"

        # Handle comma separator
        if [[ "$char" == "," && "$inside_quotes" == "false" ]]; then
            # Trim whitespace and add to array
            accum="${accum%"${accum##*[![:space:]]}"}"
            accum="${accum#"${accum%%[![:space:]]*}"}"
            arr+=("$accum")
            accum=""
            inside_value="false"
            continue
        fi

        # Handle equals sign (only outside quotes)
        if [[ "$char" == "=" && "$inside_quotes" == "false" ]]; then
            # Trim and add the column name
            accum="${accum%"${accum##*[![:space:]]}"}"
            accum="${accum#"${accum%%[![:space:]]*}"}"
            arr+=("$accum")
            accum=""
            inside_value="true"  # Next part will be a value
            continue
        fi

        # Handle quotes
        if [[ "$char" == "'" ]]; then
            inside_quotes=$([[ "$inside_quotes" == "true" ]] && echo "false" || echo "true")
            accum+="$char"
            continue
        fi

        # Skip formatting characters when not in a value
        if [[ "$inside_value" == "false" && "$inside_quotes" == "false" ]]; then
            if [[ "$char" == " " || "$char" == "(" || "$char" == ")" ]]; then
                continue
            fi
        fi

        # Add character to accumulator
        accum+="$char"
    done

    # Add the last accumulated value if exists
    if [[ -n "$accum" ]]; then
        accum="${accum%)}" 
        accum="${accum%"${accum##*[![:space:]]}"}"  
        accum="${accum#"${accum%%[![:space:]]*}"}"  
        arr+=("$accum")
    fi
}
declare -a result
tokenize_column_names_and_values "( c1 = 5 , c2 = 'rr' )" result
echo "${result[@]}" 