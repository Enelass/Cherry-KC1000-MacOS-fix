#!/bin/bash

# Setup Script for QEMU and Dependencies
# This script installs QEMU and its dependencies for the Cherry KC 1000 SC firmware update

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script variables
QEMU_DIR="$HOME/.cherry-qemu"
LOG_FILE="$QEMU_DIR/setup.log"

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
    
    # Log to file
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
    
    # Display to console
    echo -e "${color}[$level] $message${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to check if Homebrew is installed
check_homebrew() {
    log "INFO" "Checking for Homebrew..."
    if command_exists brew; then
        log "SUCCESS" "Homebrew is installed."
        return 0
    else
        log "WARNING" "Homebrew is not installed."
        return 1
    fi
}

# Function to install Homebrew
install_homebrew() {
    log "INFO" "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    if [ $? -eq 0 ]; then
        log "SUCCESS" "Homebrew installed successfully."
        # Add Homebrew to PATH for the current session
        eval "$(/opt/homebrew/bin/brew shellenv)"
        return 0
    else
        log "ERROR" "Failed to install Homebrew."
        return 1
    fi
}

# Function to check if QEMU is installed
check_qemu() {
    log "INFO" "Checking for QEMU..."
    if command_exists qemu-system-x86_64; then
        log "SUCCESS" "QEMU is installed."
        return 0
    else
        log "WARNING" "QEMU is not installed."
        return 1
    fi
}

# Function to install QEMU
install_qemu() {
    log "INFO" "Installing QEMU..."
    brew install qemu
    
    if [ $? -eq 0 ]; then
        log "SUCCESS" "QEMU installed successfully."
        return 0
    else
        log "ERROR" "Failed to install QEMU."
        return 1
    fi
}

# Function to download VirtIO drivers
download_virtio_drivers() {
    log "INFO" "Downloading VirtIO drivers..."
    
    # Create QEMU directory if it doesn't exist
    mkdir -p "$QEMU_DIR"
    
    # Download the latest stable VirtIO ISO
    curl -L -o "$QEMU_DIR/virtio-win.iso" "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
    
    if [ $? -eq 0 ]; then
        log "SUCCESS" "VirtIO drivers downloaded successfully."
        return 0
    else
        log "ERROR" "Failed to download VirtIO drivers."
        return 1
    fi
}

# Function to check for additional dependencies
check_dependencies() {
    log "INFO" "Checking for additional dependencies..."
    
    # Check for curl
    if ! command_exists curl; then
        log "WARNING" "curl is not installed."
        log "INFO" "Installing curl..."
        brew install curl
    fi
    
    # Check for wget
    if ! command_exists wget; then
        log "WARNING" "wget is not installed."
        log "INFO" "Installing wget..."
        brew install wget
    fi
    
    log "SUCCESS" "All dependencies checked."
    return 0
}

# Main function
main() {
    # Create QEMU directory if it doesn't exist
    mkdir -p "$QEMU_DIR"
    
    # Create log file
    touch "$LOG_FILE"
    
    log "INFO" "Starting QEMU setup for Cherry KC 1000 SC firmware update"
    
    # Check and install Homebrew
    if ! check_homebrew; then
        log "INFO" "Installing Homebrew..."
        if ! install_homebrew; then
            log "ERROR" "Failed to install Homebrew. Please install it manually."
            exit 1
        fi
    fi
    
    # Check and install QEMU
    if ! check_qemu; then
        log "INFO" "Installing QEMU..."
        if ! install_qemu; then
            log "ERROR" "Failed to install QEMU. Please install it manually using: brew install qemu"
            exit 1
        fi
    fi
    
    # Check additional dependencies
    check_dependencies
    
    # Download VirtIO drivers
    if ! download_virtio_drivers; then
        log "ERROR" "Failed to download VirtIO drivers."
        log "WARNING" "You can manually download VirtIO drivers from: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
        log "WARNING" "Save the downloaded file to: $QEMU_DIR/virtio-win.iso"
    fi
    
    # Add environment variable to user's shell profile
    if [ "$(uname)" = "Darwin" ]; then
        log "INFO" "Adding OBJC_DISABLE_INITIALIZE_FORK_SAFETY environment variable to shell profile..."
        
        # Determine which shell profile to use
        if [ -f "$HOME/.zshrc" ]; then
            SHELL_PROFILE="$HOME/.zshrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            SHELL_PROFILE="$HOME/.bash_profile"
        elif [ -f "$HOME/.bashrc" ]; then
            SHELL_PROFILE="$HOME/.bashrc"
        else
            SHELL_PROFILE="$HOME/.profile"
        fi
        
        # Check if the variable is already set
        if ! grep -q "OBJC_DISABLE_INITIALIZE_FORK_SAFETY" "$SHELL_PROFILE"; then
            echo "" >> "$SHELL_PROFILE"
            echo "# Added by Cherry KC 1000 SC firmware update tool" >> "$SHELL_PROFILE"
            echo "export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES" >> "$SHELL_PROFILE"
            log "INFO" "Added environment variable to $SHELL_PROFILE"
            log "INFO" "Please restart your terminal or run 'source $SHELL_PROFILE' for the changes to take effect."
        else
            log "INFO" "Environment variable already set in $SHELL_PROFILE"
        fi
    fi
    
    log "SUCCESS" "QEMU setup completed successfully."
    log "INFO" "You can now run the update_firmware.sh script to update your Cherry KC 1000 SC keyboard firmware."
    
    exit 0
}

# Run main function
main