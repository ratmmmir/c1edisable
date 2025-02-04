#!/bin/bash

#global vars
SHDIR=$(dirname "$(realpath "$0")")
TEMPDIR="$SHDIR/temp"

GRUB_FILE="/etc/default/grub"
TESTMODE=false

for arg in "$@"; do
    case $arg in
    --test)
        GRUB_FILE="$TEMPDIR/grub"
        TESTMODE=true
        ;;
    *)
        echo "Invalid option: $arg"
        exit 1
        ;;
    esac
done

# Ascii header :)
show_header() {
    cat <<"EOF"

    ><<       ><<
  ><          ><<            ><<
><>< ><   ><<<><<  ><<   ><<< ><<    ><<
  ><<   ><<   ><< ><<  ><<    ><<  ><   ><<
  ><<  ><<    ><><<   ><<     ><< ><<<<< ><<
  ><<   ><<   ><< ><<  ><<    ><< ><
  ><<     ><<<><<  ><<   ><<<><<<<  ><<<<

EOF
}

show_description() {
    if $TESTMODE; then
        echo
        echo "test mode enabled!"
    fi
}

create_backup() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup_file="${file}.bak"
        cp "$file" "$backup_file"
        echo "Create backup of $backup_file"
    else
        echo "$file not found"
    fi
}

check_grub() {
    local found=false
    if [[ -f "$GRUB_FILE" ]]; then
        local line=$(grep 'GRUB_CMDLINE_LINUX=' "$GRUB_FILE")
        if [[ "$line" =~ intel_idle.states_off=4 ]]; then
            echo "Detect: intel_idle.states_off=4"
            found=true
        fi
        if [[ "$line" =~ intel_idle.max_cstate=1 ]]; then
            echo "Detect: intel_idle.max_cstate=1"
            found=true
        fi
    else
        echo "$GRUB_FILE not found"
    fi

    if $found; then

        return 0
    else
        echo "intel.idle options not found"
        return 1
    fi
}

grub_clear() {
    check_grub

    if [[ $? -eq 0 ]]; then
        #clear
        local line=$(grep 'GRUB_CMDLINE_LINUX=' "$GRUB_FILE")
        line=${line//intel_idle.states_off=4/}
        line=${line//intel_idle.max_cstate=1/}

        sed -i "s|GRUB_CMDLINE_LINUX=.*|$line|" "$GRUB_FILE"
        echo "intel.idle options clear"
    else
        echo
    fi
}

grub_patch() {
    local new_param="$1"

    grub_clear

    local line=$(grep 'GRUB_CMDLINE_LINUX=' "$GRUB_FILE")
    if [[ -z "$line" ]]; then
        echo "GRUB_CMDLINE_LINUX=\"$new_param\"" >>"$GRUB_FILE"
        echo "Creating GRUB_CMDLINE_LINUX line with $new_param option"
    else
        local current_params=$(echo "$line" | sed 's/GRUB_CMDLINE_LINUX="\(.*\)"/\1/')
        if [[ ! "$current_params" =~ "$new_param" ]]; then
            current_params="$current_params $new_param"
            sed -i "s|GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"$current_params\"|" "$GRUB_FILE"
            echo "Creating $new_param option"
        else
            echo "Option already exists."
        fi
    fi
}

update_grub() {
    echo "updating grub..."
    DISTRO=$(detect_distro)

    case "$DISTRO" in
    fedora)
        grub2-mkconfig -o /boot/grub2/grub.cfg
        ;;

    debian | ubuntu | mint)
        update-grub
        ;;

    *)
        echo "$DISTRO has not been tested. Please check the changes and update the grub manually."
        ;;
    esac
}

check_sudo() {
    if [[ "$TESTMODE" != "true" && $(id -u) -ne 0 ]]; then
        echo "Error: this script must be run as root!" >&2
        exit 1
    fi

}

show_menu() {
    echo "Actions:"
    echo
    echo "c) Check options"
    echo
    echo "1) Add 'max_cstate' options to grub"
    echo "2) Add 'states_off' options to grub"
    echo "3) Clear all 'intel_idle' options"
    echo
    echo "9) Update-grub"
    echo "q) Exit"
    echo
}

main() {
    check_sudo

    clear

    while true; do
        show_header
        show_description
        show_menu

        read -p "Input: " choice
        echo

        case $choice in
        c) check_grub ;;
        1)
            create_backup "$GRUB_FILE"
            grub_patch "intel_idle.max_cstate=1"

            read -p "Update grub? [y/n]: " yn

            case $yn in
            y) update_grub ;;
            n) echo "exit" ;;
            *) echo "Eror: invalid input" ;;
            esac
            ;;

        2)
            create_backup "$GRUB_FILE"
            grub_patch "intel_idle.states_off=4"

            read -p "Update grub? [y/n]: " yn

            case $yn in
            y) update_grub ;;
            n) echo "exit" ;;
            *) echo "Eror: invalid input" ;;
            esac
            ;;
        3)
            create_backup "$GRUB_FILE"
            grub_clear
            ;;
        9) updade_grub ;;

        q)
            echo "Exit"
            exit 0
            ;;
        *) echo "Eror: invalid input" ;;
        esac

        echo
        read -p "Press Enter to continue..."
        clear
    done
}

main
