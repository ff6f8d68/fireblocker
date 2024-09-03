#!/bin/bash

# Define menu options
OPTIONS=("Start Fireblocker" "Stop Fireblocker" "Run Low-Intensity Scan" "Run Deep Scan" "Exit")
SELECTED=0

# Draw the menu
draw_menu() {
    clear
    echo "===================="
    echo "  Fireblocker Menu  "
    echo "===================="
    for i in "${!OPTIONS[@]}"; do
        if [ $i -eq $SELECTED ]; then
            echo -e "\e[7m${OPTIONS[$i]}\e[0m"  # Highlight selected option
        else
            echo "  ${OPTIONS[$i]}"
        fi
    done
}

# Handle user input
while true; do
    draw_menu
    read -rsn1 input

    case "$input" in
        $'\x1b')  # Detect arrow keys
            read -rsn2 -t 0.1 input
            case "$input" in
                '[A')  # Up arrow
                    ((SELECTED--))
                    if [ $SELECTED -lt 0 ]; then
                        SELECTED=$((${#OPTIONS[@]} - 1))
                    fi
                    ;;
                '[B')  # Down arrow
                    ((SELECTED++))
                    if [ $SELECTED -ge ${#OPTIONS[@]} ]; then
                        SELECTED=0
                    fi
                    ;;
            esac
            ;;
        '')  # Enter key
            case ${OPTIONS[$SELECTED]} in
                "Start Fireblocker")
                    echo "Starting Fireblocker..."
                    sudo bash fireblocker.sh start
                    ;;
                "Stop Fireblocker")
                    echo "Stopping Fireblocker..."
                    sudo bash fireblocker.sh stop
                    ;;
                "Run Low-Intensity Scan")
                    echo "Running Low-Intensity Scan..."
                    sudo bash fireblocker.sh scan-low
                    ;;
                "Run Deep Scan")
                    echo "Running Deep Scan..."
                    sudo bash fireblocker.sh scan-deep
                    ;;
                "Exit")
                    exit 0
                    ;;
            esac
            read -p "Press any key to return to the menu..." key
            ;;
    esac
done
