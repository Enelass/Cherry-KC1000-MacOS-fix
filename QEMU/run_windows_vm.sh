#!/bin/bash

# Run Windows VM Script for Cherry KC 1000 SC Firmware Update
# This script runs a Windows VM with USB passthrough for the Cherry keyboard

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
CONFIG_FILE="$SCRIPT_DIR/config/vm_config.conf"
LOG_FILE="$QEMU_DIR/vm.log"
WINDOWS_ISO=""
VIRTIO_ISO="$QEMU_DIR/virtio-win.iso"
USB_VENDOR_ID=""
USB_PRODUCT_ID=""
MEMORY="2G"
CPU_CORES="2"
DISPLAY_TYPE="default"

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

# Function to show help
show_help() {
    echo -e "${BLUE}Run Windows VM for Cherry KC 1000 SC Firmware Update${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -w, --windows FILE    Path to Windows ISO file"
    echo "  -v, --virtio FILE     Path to VirtIO drivers ISO file (default: $VIRTIO_ISO)"
    echo "  -u, --usb VID:PID     USB vendor and product ID (e.g., 046a:0011)"
    echo "  -m, --memory SIZE     Memory size for VM (default: 2G)"
    echo "  -c, --cpu CORES       Number of CPU cores (default: 2)"
    echo "  -d, --display TYPE    Display type (default: default)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --windows ~/Downloads/Win10_20H2_v2_English_x64.iso --usb 046a:0011"
    echo ""
}

# Function to load configuration from file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        log "INFO" "Loading configuration from $CONFIG_FILE"
        
        # Read memory setting
        local mem=$(grep "^memory" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
        if [ -n "$mem" ]; then
            MEMORY="$mem"
        fi
        
        # Read CPU cores setting
        local cores=$(grep "^cpu_cores" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
        if [ -n "$cores" ]; then
            CPU_CORES="$cores"
        fi
        
        # Read display type setting
        local display=$(grep "^display" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
        if [ -n "$display" ]; then
            DISPLAY_TYPE="$display"
        fi
        
        log "INFO" "Configuration loaded: Memory=$MEMORY, CPU=$CPU_CORES, Display=$DISPLAY_TYPE"
    else
        log "WARNING" "Configuration file not found: $CONFIG_FILE"
        log "INFO" "Using default settings"
    fi
}

# Function to detect Cherry keyboard
detect_keyboard() {
    log "INFO" "Detecting Cherry KC 1000 SC keyboard..."
    
    # Use the USB passthrough helper script
    if [ -f "$SCRIPT_DIR/config/usb_passthrough.sh" ]; then
        local usb_info=$("$SCRIPT_DIR/config/usb_passthrough.sh" detect)
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            # Extract vendor and product IDs from the output
            local vendor_id=$(echo "$usb_info" | grep "Vendor ID" | awk '{print $3}')
            local product_id=$(echo "$usb_info" | grep "Product ID" | awk '{print $3}')
            
            if [ -n "$vendor_id" ] && [ -n "$product_id" ]; then
                log "SUCCESS" "Cherry keyboard detected: Vendor ID=$vendor_id, Product ID=$product_id"
                USB_VENDOR_ID="$vendor_id"
                USB_PRODUCT_ID="$product_id"
                return 0
            fi
        fi
    else
        # Fallback to system_profiler if the helper script is not available
        local keyboard_info=$(system_profiler SPUSBDataType | grep -A 10 -i "Cherry" | grep -i "KC 1000")
        
        if [ -n "$keyboard_info" ]; then
            # Extract vendor and product IDs
            local vendor_id=$(system_profiler SPUSBDataType | grep -A 10 -i "Cherry" | grep -i "Vendor ID" | awk '{print $3}')
            local product_id=$(system_profiler SPUSBDataType | grep -A 10 -i "Cherry" | grep -i "Product ID" | awk '{print $3}')
            
            if [ -n "$vendor_id" ] && [ -n "$product_id" ]; then
                log "SUCCESS" "Cherry keyboard detected: Vendor ID=$vendor_id, Product ID=$product_id"
                USB_VENDOR_ID="$vendor_id"
                USB_PRODUCT_ID="$product_id"
                return 0
            fi
        fi
    fi
    
    log "WARNING" "Cherry KC 1000 SC keyboard not detected."
    return 1
}

# Function to check if VM image exists
check_vm_image() {
    if [ ! -f "$VM_IMAGE" ]; then
        log "ERROR" "VM image not found: $VM_IMAGE"
        log "INFO" "Please run setup_qemu.sh first to create the VM image."
        return 1
    fi
    
    return 0
}

# Function to run Windows VM
run_vm() {
    log "INFO" "Starting Windows VM..."
    
    # Set environment variable to avoid Objective-C runtime issues on macOS
    export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
    
    # Check if we need to run with sudo for USB access
    local sudo_cmd=""
    if [ "$(uname)" = "Darwin" ] && [ -n "$USB_VENDOR_ID" ] && [ -n "$USB_PRODUCT_ID" ]; then
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
    
    # Build QEMU command
    local qemu_cmd="$sudo_cmd qemu-system-x86_64"
    
    # Add memory and CPU options
    qemu_cmd+=" -m $MEMORY -smp $CPU_CORES -cpu max"
    
    # Add machine options
    qemu_cmd+=" -machine type=q35,accel=$accel"
    
    # Add drive options
    qemu_cmd+=" -drive file=\"$VM_IMAGE\",if=virtio"
    
    # Add CD-ROM options
    if [ -n "$WINDOWS_ISO" ]; then
        qemu_cmd+=" -cdrom \"$WINDOWS_ISO\""
    fi
    
    # Add VirtIO drivers
    if [ -f "$VIRTIO_ISO" ]; then
        qemu_cmd+=" -drive file=\"$VIRTIO_ISO\",index=1,media=cdrom"
    fi
    
    # Add USB passthrough options
    qemu_cmd+=" -usb"
    if [ -n "$USB_VENDOR_ID" ] && [ -n "$USB_PRODUCT_ID" ]; then
        log "INFO" "Using USB device: Vendor ID=0x$USB_VENDOR_ID, Product ID=0x$USB_PRODUCT_ID"
        qemu_cmd+=" -device usb-host,vendorid=0x$USB_VENDOR_ID,productid=0x$USB_PRODUCT_ID"
    fi
    
    # Add network options
    qemu_cmd+=" -net nic,model=virtio -net user"
    
    # Add display options
    qemu_cmd+=" -display $DISPLAY_TYPE,show-cursor=on -vga virtio"
    
    # Add shared folder options
    if [ -d "$QEMU_DIR/shared" ]; then
        qemu_cmd+=" -fsdev local,id=fsdev0,path=\"$QEMU_DIR/shared\",security_model=none"
        qemu_cmd+=" -device virtio-9p-pci,fsdev=fsdev0,mount_tag=shared"
    fi
    
    # Log the command
    log "INFO" "Running command: $qemu_cmd"
    
    # Run the command
    eval "$qemu_cmd"
    
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

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--windows)
            WINDOWS_ISO="$2"
            shift 2
            ;;
        -v|--virtio)
            VIRTIO_ISO="$2"
            shift 2
            ;;
        -u|--usb)
            IFS=':' read -r USB_VENDOR_ID USB_PRODUCT_ID <<< "$2"
            shift 2
            ;;
        -m|--memory)
            MEMORY="$2"
            shift 2
            ;;
        -c|--cpu)
            CPU_CORES="$2"
            shift 2
            ;;
        -d|--display)
            DISPLAY_TYPE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Create QEMU directory if it doesn't exist
mkdir -p "$QEMU_DIR"

# Create log file
touch "$LOG_FILE"

log "INFO" "Starting Windows VM for Cherry KC 1000 SC firmware update"

# Load configuration
load_config

# Check if Windows ISO is provided
if [ -z "$WINDOWS_ISO" ] && [ ! -f "$VM_IMAGE" ]; then
    log "ERROR" "Windows ISO path is required for first run. Use --windows option to specify the path."
    show_help
    exit 1
fi

# Check if Windows ISO exists
if [ -n "$WINDOWS_ISO" ] && [ ! -f "$WINDOWS_ISO" ]; then
    log "ERROR" "Windows ISO file not found: $WINDOWS_ISO"
    exit 1
fi

# Check if VM image exists
if ! check_vm_image; then
    log "ERROR" "VM image check failed."
    exit 1
fi

# Detect keyboard if USB IDs are not provided
if [ -z "$USB_VENDOR_ID" ] || [ -z "$USB_PRODUCT_ID" ]; then
    if ! detect_keyboard; then
        log "WARNING" "Cherry KC 1000 SC keyboard not detected."
        read -p "Do you want to continue without USB passthrough? (y/n): " continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            log "INFO" "Operation cancelled by user."
            exit 0
        fi
    fi
fi

# Run the VM
if ! run_vm; then
    log "ERROR" "Failed to run Windows VM."
    exit 1
fi

log "SUCCESS" "Windows VM has been shut down."
exit 0