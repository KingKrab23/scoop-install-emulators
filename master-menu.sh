#!/usr/bin/env bash

# ---------------------------------------
#  Master Menu for Emulator Management
# ---------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_menu() {
    clear
    echo "========================================="
    echo "  Emulator & Tool Management Menu"
    echo "========================================="
    echo ""
    echo "  1. Install/Sync Emulators"
    echo "  2. Update Emulators"
    echo "  3. Check Emulator Status"
    echo "  4. Install Tools (NX-Optimizer, etc.)"
    echo "  5. Exit"
    echo ""
    echo "========================================="
}

while true; do
    show_menu
    read -p "Select an option (1-5): " choice
    
    case $choice in
        1)
            echo ""
            echo "Running: ./manage-emulators.sh install"
            echo ""
            "$SCRIPT_DIR/manage-emulators.sh" install
            echo ""
            read -p "Press Enter to continue..."
            ;;
        2)
            echo ""
            echo "Running: ./manage-emulators.sh update"
            echo ""
            "$SCRIPT_DIR/manage-emulators.sh" update
            echo ""
            read -p "Press Enter to continue..."
            ;;
        3)
            echo ""
            echo "Running: ./manage-emulators.sh check"
            echo ""
            "$SCRIPT_DIR/manage-emulators.sh" check
            echo ""
            read -p "Press Enter to continue..."
            ;;
        4)
            echo ""
            echo "Running: ./install-tools.sh"
            echo ""
            "$SCRIPT_DIR/install-tools.sh"
            echo ""
            read -p "Press Enter to continue..."
            ;;
        5)
            echo ""
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo ""
            echo "Invalid option. Please select 1-5."
            sleep 2
            ;;
    esac
done
