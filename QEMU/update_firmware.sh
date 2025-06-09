#!/bin/bash

# Cherry KC 1000 SC Firmware Update Tool using QEMU
# This script sets up a QEMU Windows VM to update the Cherry KC 1000 SC keyboard firmware

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QEMU_DIR="$HOME/.cherry-qemu"
VM_IMAGE="$QEMU_DIR/windows.qcow2"
VM_SIZE="10G"
FIRMWARE_DIR="$SCRIPT_DIR/../KC1000SC_FW_1.2.1.44BETA"
DRIVER_DIR="$SCRIPT_DIR/../20200422_Driver_1.0.5.162_WHQL_signed"
WINDOWS_ISO=""
VIRTIO_ISO=""
LOG_FILE="$SCRIPT_DIR/qemu_firmware_update.log"
QUIET=false
UNINSTALL=false

# Function to display script usage
show_help() {
    echo -e "${BLUE}Cherry KC 1000 SC Firmware Update Tool (QEMU Version)${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -q, --quiet       Reduce output verbosity"
    echo "  -u, --uninstall   Remove all installed components"
    echo "  -h, --help        Show this help message"
    echo "  -w, --windows     Path to Windows ISO file"
    echo ""
    echo "Example:"
    echo "  $0 --windows ~/Downloads/Win10_20H2_v2_English_x64.iso"
    echo ""
}

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
    
    # Display to console if not in quiet mode or if it's an error/warning
    if [ "$QUIET" = false ] || [ "$level" = "ERROR" ] || [ "$level" = "WARNING" ]; then
        echo -e "${color}[$level] $message${NC}"
    fi
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
        VIRTIO_ISO="$QEMU_DIR/virtio-win.iso"
        log "SUCCESS" "VirtIO drivers downloaded successfully."
        return 0
    else
        log "ERROR" "Failed to download VirtIO drivers."
        return 1
    fi
}

# Function to create Windows VM image
create_vm_image() {
    log "INFO" "Creating Windows VM image..."
    
    # Create QEMU directory if it doesn't exist
    mkdir -p "$QEMU_DIR"
    
    # Create a QCOW2 image for Windows
    qemu-img create -f qcow2 "$VM_IMAGE" "$VM_SIZE"
    
    if [ $? -eq 0 ]; then
        log "SUCCESS" "Windows VM image created successfully."
        return 0
    else
        log "ERROR" "Failed to create Windows VM image."
        return 1
    fi
}

# Function to detect Cherry keyboard
detect_keyboard() {
    log "INFO" "Detecting Cherry KC 1000 SC keyboard..."
    
    # Use system_profiler to get USB device info
    local keyboard_info=$(system_profiler SPUSBDataType | grep -A 10 -i "Cherry" | grep -i "KC 1000")
    
    if [ -n "$keyboard_info" ]; then
        log "SUCCESS" "Cherry KC 1000 SC keyboard detected."
        
        # Extract vendor and product IDs
        local vendor_id=$(system_profiler SPUSBDataType | grep -A 10 -i "Cherry" | grep -i "Vendor ID" | awk '{print $3}')
        local product_id=$(system_profiler SPUSBDataType | grep -A 10 -i "Cherry" | grep -i "Product ID" | awk '{print $3}')
        
        log "INFO" "Keyboard Vendor ID: $vendor_id, Product ID: $product_id"
        
        # Return the vendor:product ID format needed for QEMU
        echo "$vendor_id:$product_id"
        return 0
    else
        log "WARNING" "Cherry KC 1000 SC keyboard not detected."
        return 1
    fi
}

# Function to run Windows VM with USB passthrough
run_windows_vm() {
    local usb_id=$1
    
    log "INFO" "Starting Windows VM with USB passthrough..."
    
    # Set environment variable to avoid Objective-C runtime issues on macOS
    export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
    
    log "INFO" "Using USB device: $usb_id (vendorid=0x$(echo $usb_id | cut -d':' -f1), productid=0x$(echo $usb_id | cut -d':' -f2))"
    
    # Check if we need to run with sudo for USB access
    local sudo_cmd=""
    if [ "$(uname)" = "Darwin" ]; then
        log "WARNING" "On macOS, USB passthrough may require administrator privileges."
        read -p "Do you want to run QEMU with sudo for proper USB access? (y/n): " use_sudo
        if [[ $use_sudo =~ ^[Yy]$ ]]; then
            sudo_cmd="sudo"
            log "INFO" "Using sudo for QEMU."
        fi
    fi
    
    # Determine the best acceleration method
    local accel=""
    if [ "$(uname)" = "Darwin" ]; then
        # Check if HVF is available
        if qemu-system-x86_64 -accel help 2>&1 | grep -q hvf; then
            accel="hvf"
        else
            # Fall back to TCG (software emulation)
            accel="tcg"
            log "WARNING" "Hardware virtualization (HVF) not available. Using software emulation (TCG) instead."
            log "WARNING" "This will be significantly slower."
        fi
    elif [ "$(uname)" = "Linux" ]; then
        # Check if KVM is available
        if qemu-system-x86_64 -accel help 2>&1 | grep -q kvm; then
            accel="kvm"
        else
            # Fall back to TCG (software emulation)
            accel="tcg"
            log "WARNING" "Hardware virtualization (KVM) not available. Using software emulation (TCG) instead."
            log "WARNING" "This will be significantly slower."
        fi
    else
        # Default to TCG for other platforms
        accel="tcg"
        log "WARNING" "Using software emulation (TCG)."
        log "WARNING" "This will be significantly slower."
    fi
    
    log "INFO" "Using acceleration method: $accel"
    
    # Run QEMU with Windows ISO, VirtIO drivers, and USB passthrough
    $sudo_cmd qemu-system-x86_64 \
        -m 2G \
        -smp 2 \
        -cpu max \
        -machine type=q35,accel=$accel \
        -drive file="$VM_IMAGE",if=virtio \
        -cdrom "$WINDOWS_ISO" \
        ${VIRTIO_ISO:+-drive file="$VIRTIO_ISO",index=1,media=cdrom} \
        -usb \
        -device usb-host,vendorid=0x$(echo $usb_id | cut -d':' -f1),productid=0x$(echo $usb_id | cut -d':' -f2) \
        -net nic,model=virtio \
        -net user \
        -display default,show-cursor=on \
        -vga virtio
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        log "SUCCESS" "Windows VM completed successfully."
        return 0
    else
        log "ERROR" "Windows VM exited with code $exit_code."
        log "INFO" "If you encountered USB access issues, try running the script with sudo."
        return 1
    fi
}

# Function to copy firmware files to a shared directory
prepare_firmware_files() {
    log "INFO" "Preparing firmware files for VM access..."
    
    # Create a directory to share with the VM
    mkdir -p "$QEMU_DIR/shared"
    
    # Copy firmware files
    cp -r "$FIRMWARE_DIR"/* "$QEMU_DIR/shared/"
    cp -r "$DRIVER_DIR"/* "$QEMU_DIR/shared/"
    
    if [ $? -eq 0 ]; then
        log "SUCCESS" "Firmware files prepared successfully."
        return 0
    else
        log "ERROR" "Failed to prepare firmware files."
        return 1
    fi
}

# Function to uninstall components
uninstall_components() {
    log "INFO" "Starting uninstallation process..."
    
    # Remove VM image and QEMU directory
    if [ -d "$QEMU_DIR" ]; then
        rm -rf "$QEMU_DIR"
        log "INFO" "Removed QEMU directory."
    fi
    
    # Ask if user wants to uninstall QEMU
    read -p "Do you want to uninstall QEMU? (y/n): " uninstall_qemu
    if [[ $uninstall_qemu =~ ^[Yy]$ ]]; then
        brew uninstall qemu
        log "INFO" "Uninstalled QEMU."
    fi
    
    # Ask if user wants to uninstall Homebrew
    read -p "Do you want to uninstall Homebrew? (y/n): " uninstall_homebrew
    if [[ $uninstall_homebrew =~ ^[Yy]$ ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
        log "INFO" "Uninstalled Homebrew."
    fi
    
    log "SUCCESS" "Uninstallation completed."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -u|--uninstall)
            UNINSTALL=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -w|--windows)
            WINDOWS_ISO="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Create log file
touch "$LOG_FILE"
log "INFO" "Starting Cherry KC 1000 SC Firmware Update Tool (QEMU Version)"

# Check if uninstall mode is selected
if [ "$UNINSTALL" = true ]; then
    log "INFO" "Uninstall mode selected."
    uninstall_components
    exit 0
fi

# Check if Windows ISO is provided
if [ -z "$WINDOWS_ISO" ]; then
    log "ERROR" "Windows ISO path is required. Use --windows option to specify the path."
    show_help
    exit 1
fi

# Check if Windows ISO exists
if [ ! -f "$WINDOWS_ISO" ]; then
    log "ERROR" "Windows ISO file not found: $WINDOWS_ISO"
    exit 1
fi

# Check and install dependencies
if ! check_homebrew; then
    log "INFO" "Installing Homebrew..."
    if ! install_homebrew; then
        log "ERROR" "Failed to install Homebrew. Please install it manually."
        exit 1
    fi
fi

if ! check_qemu; then
    log "INFO" "Installing QEMU..."
    if ! install_qemu; then
        log "ERROR" "Failed to install QEMU. Please install it manually using: brew install qemu"
        exit 1
    fi
fi

# Download VirtIO drivers
if ! download_virtio_drivers; then
    log "WARNING" "Failed to download VirtIO drivers."
    log "WARNING" "You can manually download VirtIO drivers from: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
    log "WARNING" "Save the downloaded file to: $QEMU_DIR/virtio-win.iso"
    log "INFO" "Continuing without VirtIO drivers..."
    VIRTIO_ISO=""
fi

# Create VM image if it doesn't exist
if [ ! -f "$VM_IMAGE" ]; then
    if ! create_vm_image; then
        log "ERROR" "Failed to create VM image."
        exit 1
    fi
fi

# Prepare firmware files
if ! prepare_firmware_files; then
    log "ERROR" "Failed to prepare firmware files."
    exit 1
fi

# Detect keyboard
usb_id=$(detect_keyboard)
if [ $? -ne 0 ]; then
    log "WARNING" "Cherry KC 1000 SC keyboard not detected."
    read -p "Do you want to continue anyway? (y/n): " continue_anyway
    if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
        log "INFO" "Operation cancelled by user."
        exit 0
    fi
    
    # Ask for manual vendor and product IDs
    read -p "Enter keyboard vendor ID (e.g., 046a): " vendor_id
    read -p "Enter keyboard product ID (e.g., 0011): " product_id
    usb_id="${vendor_id}:${product_id}"
fi

# Confirm firmware update
read -p "Ready to start Windows VM for firmware update. Continue? (y/n): " confirm_update
if [[ ! $confirm_update =~ ^[Yy]$ ]]; then
    log "INFO" "Operation cancelled by user."
    exit 0
fi

# Run Windows VM with USB passthrough
log "INFO" "Starting Windows VM. Please follow these steps in the VM:"
log "INFO" "1. Install Windows (select 'I don't have a product key' if asked)"
log "INFO" "2. When prompted for drivers during installation, browse to the VirtIO CD"
log "INFO" "3. After Windows is installed, access the shared folder at Z:\\"
log "INFO" "4. Install the Cherry keyboard driver from the shared folder"
log "INFO" "5. Run the firmware update tool from the shared folder"
log "INFO" "6. Shut down Windows when the update is complete"

if ! run_windows_vm "$usb_id"; then
    log "ERROR" "Failed to run Windows VM."
    exit 1
fi

log "SUCCESS" "Windows VM has been shut down."
log "INFO" "If the firmware update was successful, your keyboard should now be updated."
log "INFO" "You can verify the firmware version by reconnecting the keyboard and checking the device information."

# Ask if user wants to keep the VM
read -p "Do you want to keep the Windows VM for future updates? (y/n): " keep_vm
if [[ ! $keep_vm =~ ^[Yy]$ ]]; then
    rm -f "$VM_IMAGE"
    log "INFO" "Windows VM image removed."
fi

log "SUCCESS" "Cherry KC 1000 SC firmware update process completed."
exit 0