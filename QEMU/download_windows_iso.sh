#!/bin/bash

# Script to download Windows ISO for QEMU-based firmware update

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script variables
QEMU_DIR="$HOME/.cherry-qemu"
ISO_DIR="$QEMU_DIR/iso"
WIN_ISO="$ISO_DIR/windows.iso"

# Function to log messages
log() {
    local level=$1
    local message=$2
    local color=$NC
    
    case $level in
        "INFO") color=$BLUE ;;
        "SUCCESS") color=$GREEN ;;
        "WARNING") color=$YELLOW ;;
        "ERROR") color=$RED ;;
    esac
    
    # Display to console
    echo -e "${color}[$level] $message${NC}"
}

# Create directories if they don't exist
mkdir -p "$ISO_DIR"

log "INFO" "Windows ISO Downloader for Cherry KC 1000 SC Firmware Update"
log "INFO" "This script will help you download a Windows ISO for use with the QEMU-based firmware update solution."
log "INFO" ""

# Explain the options
log "INFO" "There are several ways to obtain a Windows ISO:"
log "INFO" "1. Download from Microsoft's website (requires a web browser)"
log "INFO" "2. Use a direct download link (if available)"
log "INFO" "3. Use an existing ISO file"
log "INFO" ""

# Ask the user which method they prefer
read -p "Which method would you like to use? (1/2/3): " method

case $method in
    1)
        log "INFO" "Opening Microsoft's Windows 10 download page in your default browser..."
        log "INFO" "Please follow these steps:"
        log "INFO" "1. Select 'Windows 10' when prompted"
        log "INFO" "2. Select your language"
        log "INFO" "3. Choose '64-bit Download'"
        log "INFO" "4. Save the ISO to: $WIN_ISO"
        
        # Open the Microsoft download page
        open "https://www.microsoft.com/en-us/software-download/windows10ISO"
        
        log "INFO" "After downloading, please run the update_firmware.sh script with:"
        log "INFO" "./QEMU/update_firmware.sh --windows $WIN_ISO"
        ;;
    2)
        log "WARNING" "Direct download links for Windows ISOs are not officially provided by Microsoft."
        log "WARNING" "Using unofficial sources may violate terms of service or download potentially modified software."
        log "INFO" "It's recommended to use method 1 instead."
        
        read -p "Do you still want to proceed with a direct download? (y/n): " proceed
        if [[ $proceed =~ ^[Yy]$ ]]; then
            log "INFO" "Please enter a direct download URL for a Windows ISO:"
            read -p "URL: " download_url
            
            log "INFO" "Downloading Windows ISO from: $download_url"
            log "INFO" "This may take a while depending on your internet connection..."
            
            curl -L -o "$WIN_ISO" "$download_url"
            
            if [ $? -eq 0 ]; then
                log "SUCCESS" "Windows ISO downloaded successfully to: $WIN_ISO"
                log "INFO" "You can now run the update_firmware.sh script with:"
                log "INFO" "./QEMU/update_firmware.sh --windows $WIN_ISO"
            else
                log "ERROR" "Failed to download Windows ISO."
                log "INFO" "Please try method 1 or 3 instead."
            fi
        else
            log "INFO" "Download cancelled."
        fi
        ;;
    3)
        log "INFO" "Please enter the path to your existing Windows ISO file:"
        read -p "Path: " existing_iso
        
        if [ -f "$existing_iso" ]; then
            log "INFO" "Copying ISO to: $WIN_ISO"
            cp "$existing_iso" "$WIN_ISO"
            
            if [ $? -eq 0 ]; then
                log "SUCCESS" "Windows ISO copied successfully to: $WIN_ISO"
                log "INFO" "You can now run the update_firmware.sh script with:"
                log "INFO" "./QEMU/update_firmware.sh --windows $WIN_ISO"
            else
                log "ERROR" "Failed to copy Windows ISO."
                log "INFO" "Please make sure you have write permissions to $ISO_DIR"
            fi
        else
            log "ERROR" "File not found: $existing_iso"
            log "INFO" "Please check the path and try again."
        fi
        ;;
    *)
        log "ERROR" "Invalid option. Please run the script again and select 1, 2, or 3."
        ;;
esac

log "INFO" ""
log "INFO" "After obtaining a Windows ISO, run the update_firmware.sh script with:"
log "INFO" "./QEMU/update_firmware.sh --windows $WIN_ISO"