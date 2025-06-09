#!/bin/bash

# USB Passthrough Helper Script for Cherry KC 1000 SC Keyboard
# This script helps detect and configure USB passthrough for QEMU

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to detect Cherry keyboard
detect_cherry_keyboard() {
    echo -e "${BLUE}Detecting Cherry KC 1000 SC keyboard...${NC}"
    
    # Hardcoded values for Cherry KC 1000 SC based on previous detection
    local vendor_id="046a"
    local product_id="00a1"
    
    # Use system_profiler to check if the keyboard is connected
    local keyboard_info=$(system_profiler SPUSBDataType | grep -i "KC 1000")
    
    if [ -n "$keyboard_info" ]; then
        echo -e "${GREEN}Cherry KC 1000 SC keyboard detected.${NC}"
        echo "Keyboard Vendor ID: 0x$vendor_id, Product ID: 0x$product_id"
        echo "$vendor_id:$product_id"
        return 0
    else
        # Try alternative detection method for any Cherry keyboard
        local alt_keyboard_info=$(system_profiler SPUSBDataType | grep -i "Cherry")
        
        if [ -n "$alt_keyboard_info" ]; then
            echo -e "${GREEN}Cherry keyboard detected.${NC}"
            echo "Keyboard Vendor ID: 0x$vendor_id, Product ID: 0x$product_id"
            echo "$vendor_id:$product_id"
            return 0
        else
            echo -e "${YELLOW}Cherry KC 1000 SC keyboard not detected.${NC}"
            return 1
        fi
    fi
}

# Function to list all USB devices
list_usb_devices() {
    echo -e "${BLUE}Listing all USB devices:${NC}"
    system_profiler SPUSBDataType
}

# Function to generate QEMU USB passthrough command
generate_usb_passthrough_cmd() {
    local vendor_id=$1
    local product_id=$2
    
    if [ -z "$vendor_id" ] || [ -z "$product_id" ]; then
        echo -e "${RED}Error: Vendor ID and Product ID are required.${NC}"
        return 1
    fi
    
    echo "-usb -device usb-host,vendorid=0x$vendor_id,productid=0x$product_id"
    return 0
}

# Main function
main() {
    local command=$1
    
    case $command in
        "detect")
            detect_cherry_keyboard
            ;;
        "list")
            list_usb_devices
            ;;
        "generate")
            if [ -z "$2" ] || [ -z "$3" ]; then
                echo -e "${RED}Error: Vendor ID and Product ID are required.${NC}"
                echo "Usage: $0 generate <vendor_id> <product_id>"
                return 1
            fi
            generate_usb_passthrough_cmd "$2" "$3"
            ;;
        *)
            echo "USB Passthrough Helper for Cherry KC 1000 SC Keyboard"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  detect              Detect Cherry KC 1000 SC keyboard"
            echo "  list                List all USB devices"
            echo "  generate <vid> <pid> Generate QEMU USB passthrough command"
            echo ""
            echo "Examples:"
            echo "  $0 detect"
            echo "  $0 generate 046a 0011"
            ;;
    esac
}

# Run main function with all arguments
main "$@"