#!/usr/bin/env bash
#shellcheck disable=SC1087,SC2059

# source https://github.com/mamiu/dotfiles/blob/main/install/utils/multiselect.sh

####################### DESCRIPTION: #######################
#
# multiselect is a pure bash implementation of a multi
# selection menu.
#
# If "true" is passed as first argument a help (similar to
# the overview in section "USAGE") will be printed before
# showing the options. Any other value will hide it.
#
# The result will be stored as an array in a variable
# that is passed to multiselect as second argument.
#
# The third argument takes an array that contains all
# available options.
#
# The last argument is optional and can be used to
# preselect certain options. If used it must be an array
# that has a value of "true" for every index of the options
# array that should be preselected.
#
########################## USAGE: ##########################
#
#   j or ↓        => down
#   k or ↑        => up
#   ⎵ (Space)     => toggle selection
#   ⏎ (Enter)     => confirm selection
#
######################### EXAMPLE: #########################
#
# source <(curl -sL multiselect.miu.io)
#
# my_options=(   "Option 1"  "Option 2"  "Option 3" )
# preselection=( "true"      "true"      "false"    )
#
# multiselect "true" result my_options preselection
#
# idx=0
# for option in "${my_options[@]}"; do
#     echo -e "$option\t=> ${result[idx]}"
#     ((idx++))
# done
#
############################################################

function multiselect {
    if [[ $1 = "true" ]]; then
        echo -e "j or ↓\t\t=> pra baixo"
        echo -e "k or ↑\t\t=> pra cima"
        echo -e "⎵ (Space)\t=> seleciona"
        echo -e "⏎ (Enter)\t=> confirma"
        echo
    fi

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()   { printf "$ESC[?25h"; }
    cursor_blink_off()  { printf "$ESC[?25l"; }
    cursor_to()         { printf "$ESC[$1;${2:-1}H"; }
    print_inactive()    { printf "$2   $1 "; }
    print_active()      { printf "$2  $ESC[7m $1 $ESC[27m"; }
#shellcheck disable=SC2162,SC2034
    get_cursor_row()    { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo "${ROW#*[}"; }

    local return_value=$2
    local -n options=$3
    local -n defaults=$4

    local selected=()
    for ((i=0; i<${#options[@]}; i++)); do
        if [[ ${defaults[i]} = "true" ]]; then
            selected+=("true")
        else
            selected+=("false")
        fi
        printf "\n"
    done

    # determine current screen position for overwriting the options
    local lastrow
    lastrow=$(get_cursor_row)
    local startrow=$(("$lastrow" - ${#options[@]}))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    key_input() {
        local key
        IFS= read -rsn1 key 2>/dev/null >&2
        if [[ $key = ""      ]]; then echo enter; fi;
        if [[ $key = $'\x20' ]]; then echo space; fi;
        if [[ $key = "k" ]]; then echo up; fi;
        if [[ $key = "j" ]]; then echo down; fi;
        if [[ $key = $'\x1b' ]]; then
            read -rsn2 key
            if [[ $key = [A || $key = k ]]; then echo up;    fi;
            if [[ $key = [B || $key = j ]]; then echo down;  fi;
        fi 
    }

    toggle_option() {
        local option=$1
        if [[ ${selected[option]} == true ]]; then
            selected[option]=false
        else
            selected[option]=true
        fi
    }

    print_options() {
        # print options by overwriting the last lines
        local idx=0
        for option in "${options[@]}"; do
            local prefix="[ ]"
            if [[ ${selected[idx]} == true ]]; then
              prefix="[\e[38;5;46m✔\e[0m]"
            fi

            cursor_to $(("$startrow" + "$idx"))
            if [ $idx -eq "$1" ]; then
                print_active "$option" "$prefix"
            else
                print_inactive "$option" "$prefix"
            fi
            ((idx++))
        done
    }

    local active=0
    while true; do
        print_options $active

        # user key control
        case $(key_input) in
            space)  toggle_option $active;;
            enter)  print_options -1; break;;
            up)     ((active--));
                    if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi;;
            down)   ((active++));
                    if [ $active -ge ${#options[@]} ]; then active=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to "$lastrow"
    printf "\n"
    cursor_blink_on

    eval "$return_value"='("${selected[@]}")'
}

# I like to put up longer descriptions on the menu, but having the index to work with where needed

my_options=(   "Option 1"  "Option 2"  "Option 3" )
my_index=(     "opt1"      "opt2"      "opt3"     )
#shellcheck disable=SC2034
preselection=( "true"      "true"      "false"    )
result=""

multiselect true result my_options preselection

# one way I came up to use it then, is...

#shellcheck disable=SC2154
for i in "${!result[@]}"; do
    true_selection=${result[i]}
    if [[ "$true_selection" == true ]]; then
        index_type="${my_index[i]}"
        options_desc="${my_options[i]}"
        echo "Running: $options_desc"
        # echo "Recon type: $recon_type"
        command -v "$index_type"
    fi
done
