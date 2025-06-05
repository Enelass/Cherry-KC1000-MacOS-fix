#!/bin/bash
#
# Cherry KC 1000 SC Firmware Update Tool for macOS
# 
# This script automates the process of updating the firmware for Cherry KC 1000 SC keyboards
# on macOS by installing and configuring Wine to run the Windows-based firmware update tool.
#
# Author: Florian Bidabe
# License: MIT
# Version: 1.0.5
# Date: June 2, 2025

# Set error handling (but don't exit on all errors)
set +e

# Default options
QUIET_MODE=false
UNINSTALL_MODE=false

# Default options
DEBUG_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        -u|--uninstall)
            UNINSTALL_MODE=true
            shift
            ;;
        -d|--debug)
            DEBUG_MODE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -q, --quiet     Reduce output verbosity"
            echo "  -u, --uninstall Remove all installed components"
            echo "  -d, --debug     Enable debug mode with additional logging"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FIRMWARE_DIR="$SCRIPT_DIR/KC1000SC_FW_1.2.1.44BETA"
FIRMWARE_EXE="$FIRMWARE_DIR/boot4_upload.exe"
FIRMWARE_FILE="$FIRMWARE_DIR/CHKBD-1.2.1.44-20250324T205718-1DF21CCF5F7E-RELEASE.sfu"

# Wine prefix specifically for this firmware update
export WINEPREFIX="$HOME/.wine-cherry-firmware"

# Log file path
LOG_FILE="$SCRIPT_DIR/cherry_firmware_update.log"

# Function to display error messages and exit
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    echo "$(date): ERROR: $1" >> "$LOG_FILE"
    exit 1
}

# Function to display success messages
success_msg() {
    echo -e "${GREEN}$1${NC}"
    echo "$(date): SUCCESS: $1" >> "$LOG_FILE"
}

# Function to display warning messages
warning_msg() {
    echo -e "${YELLOW}$1${NC}"
    echo "$(date): WARNING: $1" >> "$LOG_FILE"
}

# Function to display info messages
info_msg() {
    echo "$(date): INFO: $1" >> "$LOG_FILE"
    if [ "$QUIET_MODE" = false ]; then
        echo -e "${BLUE}$1${NC}"
    fi
}

# Function to log verbose information (only to log file)
log_verbose() {
    echo "$(date): VERBOSE: $1" >> "$LOG_FILE"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if XQuartz is installed
xquartz_installed() {
    [ -d "/Applications/Utilities/XQuartz.app" ] || [ -d "/Applications/XQuartz.app" ]
}

# Function to check if a smart card is inserted
check_smart_card() {
    info_msg "Checking for smart card..."
    
    # Try to detect a smart card using system_profiler
    # Look for ATR: which indicates a card is present, or check if "no card present" is NOT in the output
    if system_profiler SPSmartCardsDataType 2>/dev/null | grep -i "ATR:" >/dev/null || ! system_profiler SPSmartCardsDataType 2>/dev/null | grep -i "no card present" >/dev/null; then
        success_msg "Smart card detected!"
        return 0
    else
        warning_msg "No smart card detected."
        warning_msg "The firmware update may fail without a smart card."
        warning_msg "Please insert a readable smart card into the keyboard's card reader."
        
        read -p "Continue without smart card? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info_msg "Exiting. Please insert a smart card and try again."
            exit 0
        fi
        
        warning_msg "Continuing without smart card..."
        return 1
    fi
}

# Function to check if the Cherry keyboard is connected
check_keyboard_connected() {
    info_msg "Checking for Cherry KC 1000 SC keyboard..."
    
    # Try to detect the keyboard using system_profiler
    if system_profiler SPUSBDataType 2>/dev/null | grep -i "Cherry" >/dev/null; then
        success_msg "Cherry keyboard detected!"
        
        # Check if a smart card is inserted
        check_smart_card
        
        return 0
    else
        warning_msg "Cherry keyboard not detected."
        warning_msg "Please make sure your keyboard is properly connected."
        
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info_msg "Exiting. Please reconnect your keyboard and try again."
            exit 0
        fi
        
        warning_msg "Continuing without detected keyboard..."
        return 1
    fi
}

# Function to check if required files exist
check_required_files() {
    info_msg "Checking for required firmware files..."
    
    if [ ! -f "$FIRMWARE_EXE" ]; then
        error_exit "Firmware update executable not found at: $FIRMWARE_EXE"
    fi
    
    if [ ! -f "$FIRMWARE_FILE" ]; then
        error_exit "Firmware file not found at: $FIRMWARE_FILE"
    fi
    
    success_msg "All required firmware files found"
    log_verbose "Firmware executable: $FIRMWARE_EXE"
    log_verbose "Firmware file: $FIRMWARE_FILE"
}

# Function to install Homebrew if not already installed
install_homebrew() {
    if ! command_exists brew; then
        echo "Installing Homebrew..."
        info_msg "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || error_exit "Failed to install Homebrew"
        
        # Add Homebrew to PATH for the current session if it was just installed
        eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null
        
        BREW_PREFIX=$(brew --prefix)
        log_verbose "Homebrew installed at: $BREW_PREFIX"
        success_msg "Homebrew installed successfully"
    else
        BREW_PREFIX=$(brew --prefix)
        log_verbose "Homebrew is already installed at: $BREW_PREFIX"
        info_msg "Homebrew is already installed"
    fi
}

# Function to install XQuartz if not already installed
install_xquartz() {
    if ! xquartz_installed; then
        echo "Installing XQuartz..."
        info_msg "XQuartz not found. Installing XQuartz..."
        brew install --cask xquartz || error_exit "Failed to install XQuartz"
        
        warning_msg "XQuartz installation requires logging out and back in to take effect."
        warning_msg "Please run this script again after logging back in."
        
        read -p "Log out now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            osascript -e 'tell application "System Events" to log out'
            exit 0
        else
            warning_msg "Please log out and log back in manually, then run this script again."
            exit 0
        fi
    else
        if [ -d "/Applications/Utilities/XQuartz.app" ]; then
            XQUARTZ_PATH="/Applications/Utilities/XQuartz.app"
        else
            XQUARTZ_PATH="/Applications/XQuartz.app"
        fi
        log_verbose "XQuartz is already installed at: $XQUARTZ_PATH"
        info_msg "XQuartz is already installed"
    fi
}

# Function to install Wine if not already installed
install_wine() {
    if ! command_exists wine; then
        echo "Installing Wine..."
        info_msg "Wine not found. Installing Wine..."
        
        # Install Wine using Homebrew
        brew install --cask --no-quarantine wine-stable || error_exit "Failed to install Wine"
        
        WINE_PATH=$(command -v wine)
        log_verbose "Wine installed at: $WINE_PATH"
        success_msg "Wine installed successfully"
    else
        WINE_PATH=$(command -v wine)
        log_verbose "Wine is already installed at: $WINE_PATH"
        info_msg "Wine is already installed"
    fi
    
    # Install winetricks if not already installed
    if ! command_exists winetricks; then
        echo "Installing Winetricks..."
        info_msg "Winetricks not found. Installing Winetricks..."
        brew install winetricks || error_exit "Failed to install Winetricks"
        WINETRICKS_PATH=$(command -v winetricks)
        log_verbose "Winetricks installed at: $WINETRICKS_PATH"
        success_msg "Winetricks installed successfully"
    else
        WINETRICKS_PATH=$(command -v winetricks)
        log_verbose "Winetricks is already installed at: $WINETRICKS_PATH"
        info_msg "Winetricks is already installed"
    fi
}

# Function to install Cherry KC1000 drivers in Wine
install_cherry_drivers() {
    echo "Installing Cherry KC1000 drivers..."
    info_msg "Installing Cherry KC1000 drivers in Wine..."
    
    # Define driver paths
    DRIVER_DIR="$SCRIPT_DIR/20200422_Driver_1.0.5.162_WHQL_signed"
    
    # Check if driver directory exists
    if [ ! -d "$DRIVER_DIR" ]; then
        warning_msg "Cherry KC1000 driver directory not found at: $DRIVER_DIR"
        warning_msg "Continuing without driver installation..."
        return 1
    fi
    
    # Determine Wine architecture (x86 or x64)
    WINE_ARCH=$(wine cmd /c "echo %PROCESSOR_ARCHITECTURE%" 2>/dev/null | tr -d '\r\n')
    
    # Select appropriate driver folder based on Wine architecture
    if [[ "$WINE_ARCH" == *"64"* ]]; then
        log_verbose "Detected 64-bit Wine architecture."
        DRIVER_SRC="$DRIVER_DIR/Win10_x64"
    else
        log_verbose "Detected 32-bit Wine architecture."
        DRIVER_SRC="$DRIVER_DIR/Win10_x86"
    fi
    
    # Check if driver source directory exists
    if [ ! -d "$DRIVER_SRC" ]; then
        warning_msg "Cherry KC1000 driver files not found at: $DRIVER_SRC"
        warning_msg "Continuing without driver installation..."
        return 1
    fi
    
    # Create destination directory in Wine C: drive
    WINE_C_DRIVE="$WINEPREFIX/drive_c"
    WINE_DRIVER_DIR="$WINE_C_DRIVE/Cherry_Drivers"
    
    # Create directory if it doesn't exist
    mkdir -p "$WINE_DRIVER_DIR"
    
    # Copy driver files
    log_verbose "Copying driver files to Wine C: drive..."
    cp "$DRIVER_SRC"/* "$WINE_DRIVER_DIR/" || {
        warning_msg "Failed to copy driver files."
        warning_msg "Continuing without driver installation..."
        return 1
    }
    
    # Create a batch file to install the driver
    log_verbose "Creating driver installation batch file..."
    INSTALL_BAT="$WINE_DRIVER_DIR/install_driver.bat"
    
    # Determine the .inf file name based on architecture
    if [[ "$WINE_ARCH" == *"64"* ]]; then
        INF_FILE="kc1000x64.inf"
    else
        INF_FILE="kc1000x86.inf"
    fi
    
    # Create the batch file content
    cat > "$INSTALL_BAT" << EOF
@echo off
echo Installing Cherry KC1000 SC driver...
rundll32 setupapi.dll,InstallHinfSection DefaultInstall 132 %~dp0\\$INF_FILE
echo Driver installation completed.
EOF
    
    # Run the batch file to install the driver
    log_verbose "Installing driver using Windows setup API..."
    if [ "$QUIET_MODE" = true ]; then
        wine cmd /c "C:\\Cherry_Drivers\\install_driver.bat" > /dev/null 2>&1 || warning_msg "Driver installation may not have completed successfully."
    else
        wine cmd /c "C:\\Cherry_Drivers\\install_driver.bat" || warning_msg "Driver installation may not have completed successfully."
    fi
    
    # Configure registry for the driver
    log_verbose "Configuring registry for Cherry KC1000 driver..."
    
    # Create a temporary registry file
    WINE_REG_FILE=$(mktemp)
    
    # Add registry entries for the driver
    cat > "$WINE_REG_FILE" << EOF
REGEDIT4

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\KC1000SC]
"Type"=dword:00000001
"Start"=dword:00000002
"ErrorControl"=dword:00000001
"DisplayName"="Cherry KC 1000 SC Driver"
"Group"="SmartCardReader"

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\KC1000SC\\Parameters]
"DriverPath"="C:\\\\Cherry_Drivers\\\\$INF_FILE"
EOF
    
    # Import the registry file
    wine regedit "$WINE_REG_FILE" > /dev/null 2>&1 || warning_msg "Failed to import driver registry settings"
    
    # Clean up temporary registry file
    rm -f "$WINE_REG_FILE"
    
    success_msg "Cherry KC1000 driver installation completed."
    return 0
}

# Function to configure Wine for the firmware update
configure_wine() {
    echo "Configuring Wine environment..."
    info_msg "Configuring Wine for firmware update..."
    
    # Initialize Wine if needed
    if [ ! -d "$WINEPREFIX" ]; then
        log_verbose "Creating new Wine prefix at $WINEPREFIX"
        wineboot --init || error_exit "Failed to initialize Wine"
    fi
    
    # Check if Windows components are already installed
    COMPONENTS_MARKER="$WINEPREFIX/.cherry_components_installed"
    
    if [ ! -f "$COMPONENTS_MARKER" ]; then
        # Show a simplified message to the user
        echo "Installing necessary Windows components (this may take a few minutes)..."
        log_verbose "Installing necessary Windows components for USB device access..."
        
        # Create a temporary file to capture and filter winetricks output
        WINETRICKS_LOG=$(mktemp)
        
        # Set Windows version to Windows 7
        if [ "$QUIET_MODE" = true ]; then
            # In quiet mode, completely suppress all output
            winetricks -q win7 > /dev/null 2>&1 || warning_msg "Failed to set Windows version to Windows 7"
        else
            # In normal mode, capture output and only show real errors
            winetricks -q win7 > "$WINETRICKS_LOG" 2>&1 || {
                # Only show actual errors, not warnings
                grep -v "warning:" "$WINETRICKS_LOG" | grep -v "^------" >&2
                warning_msg "Failed to set Windows version to Windows 7"
            }
        fi
        
        # Install .NET Framework 4.0 (required by many firmware updaters)
        if [ "$QUIET_MODE" = true ]; then
            # In quiet mode, completely suppress all output
            winetricks -q dotnet40 > /dev/null 2>&1 || warning_msg "Failed to install .NET Framework 4.0"
        else
            # In normal mode, capture output and only show real errors
            winetricks -q dotnet40 > "$WINETRICKS_LOG" 2>&1 || {
                # Only show actual errors, not warnings
                grep -v "warning:" "$WINETRICKS_LOG" | grep -v "^------" >&2
                warning_msg "Failed to install .NET Framework 4.0"
            }
        fi
        
        # Install additional components for USB and smart card access
        log_verbose "Installing additional components for smart card reader access..."
        
        # Install USB support components
        if [ "$QUIET_MODE" = true ]; then
            winetricks -q wineusb > /dev/null 2>&1 || warning_msg "Failed to install Wine USB support"
        else
            winetricks -q wineusb > "$WINETRICKS_LOG" 2>&1 || {
                grep -v "warning:" "$WINETRICKS_LOG" | grep -v "^------" >&2
                warning_msg "Failed to install Wine USB support"
            }
        fi
        
        # Clean up temporary log file
        rm -f "$WINETRICKS_LOG"
        
        # Create marker file to indicate components are installed
        touch "$COMPONENTS_MARKER"
        
        success_msg "Windows components installed successfully"
        log_verbose "Windows components installed at: $WINEPREFIX"
        log_verbose "Windows 7 configuration: $WINEPREFIX/drive_c/windows/system32"
        log_verbose ".NET Framework 4.0: $WINEPREFIX/drive_c/windows/Microsoft.NET/Framework"
    else
        log_verbose "Windows components already installed at: $WINEPREFIX"
        log_verbose "Components marker file: $COMPONENTS_MARKER"
    fi
    
    # Configure Wine registry for better USB device access
    log_verbose "Configuring Wine registry for smart card reader access..."
    
    # Create a temporary registry file
    WINE_REG_FILE=$(mktemp)
    
    # Add registry entries for USB device access
    cat > "$WINE_REG_FILE" << EOF
REGEDIT4

[HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Services\\WineSmart]
"Type"=dword:00000001
"Start"=dword:00000002
"ErrorControl"=dword:00000001
"DisplayName"="Wine Smart Card Service"
"Group"="SmartCardReader"

[HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Services\\Wineusb]
"Type"=dword:00000001
"Start"=dword:00000002
"ErrorControl"=dword:00000001
"DisplayName"="Wine USB Service"
"Group"="System Bus Extender"
EOF
    
    # Import the registry file
    wine regedit "$WINE_REG_FILE" > /dev/null 2>&1 || warning_msg "Failed to import registry settings"
    
    # Clean up temporary registry file
    rm -f "$WINE_REG_FILE"
    
    # Install Cherry KC1000 drivers
    install_cherry_drivers
    
    success_msg "Wine configuration completed."
}

# Function to uninstall all components
uninstall_components() {
    echo "========================================================"
    echo "  Cherry KC 1000 SC Firmware Update Tool - Uninstaller"
    echo "========================================================"
    echo
    
    warning_msg "This will remove all components installed by this script:"
    echo "1. Wine prefix directory: $WINEPREFIX"
    echo "2. Wine and winetricks (installed via Homebrew)"
    echo "3. XQuartz (installed via Homebrew)"
    echo
    
    read -p "Are you sure you want to proceed with uninstallation? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info_msg "Uninstallation cancelled."
        exit 0
    fi
    
    # Remove Wine prefix
    if [ -d "$WINEPREFIX" ]; then
        info_msg "Removing Wine prefix at: $WINEPREFIX"
        rm -rf "$WINEPREFIX" || warning_msg "Failed to remove Wine prefix"
        success_msg "Wine prefix removed successfully."
    else
        info_msg "Wine prefix not found at: $WINEPREFIX"
    fi
    
    # Check if Homebrew is installed
    if command_exists brew; then
        # Uninstall Wine
        if command_exists wine; then
            info_msg "Uninstalling Wine..."
            brew uninstall --cask wine-stable || warning_msg "Failed to uninstall Wine"
            success_msg "Wine uninstalled successfully."
        else
            info_msg "Wine is not installed."
        fi
        
        # Uninstall winetricks
        if command_exists winetricks; then
            info_msg "Uninstalling winetricks..."
            brew uninstall winetricks || warning_msg "Failed to uninstall winetricks"
            success_msg "Winetricks uninstalled successfully."
        else
            info_msg "Winetricks is not installed."
        fi
        
        # Uninstall XQuartz
        if xquartz_installed; then
            info_msg "Uninstalling XQuartz..."
            brew uninstall --cask xquartz || warning_msg "Failed to uninstall XQuartz"
            success_msg "XQuartz uninstalled successfully."
        else
            info_msg "XQuartz is not installed."
        fi
        
        # Ask if user wants to uninstall Homebrew
        echo
        read -p "Do you want to uninstall Homebrew as well? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info_msg "Uninstalling Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" || warning_msg "Failed to uninstall Homebrew"
            success_msg "Homebrew uninstalled successfully."
        else
            info_msg "Keeping Homebrew installed."
        fi
    else
        info_msg "Homebrew is not installed."
    fi
    
    echo
    success_msg "Uninstallation completed."
    exit 0
}

# Function to run the firmware update
run_firmware_update() {
    echo "Preparing to run firmware update..."
    info_msg "Preparing to run firmware update..."
    
    # Change to the firmware directory
    cd "$FIRMWARE_DIR" || error_exit "Failed to change to firmware directory"
    
    # Confirm before proceeding
    echo
    warning_msg "IMPORTANT: The firmware update process will now begin."
    warning_msg "Do not disconnect your keyboard during the update process."
    warning_msg "This may take several minutes to complete."
    echo
    read -p "Continue with firmware update? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info_msg "Firmware update cancelled."
        exit 0
    fi
    
    # Copy firmware files to Wine C: drive for better access
    echo "Copying firmware files..."
    log_verbose "Copying firmware files to Wine C: drive..."
    WINE_C_DRIVE="$WINEPREFIX/drive_c"
    WINE_FIRMWARE_DIR="$WINE_C_DRIVE/Cherry_Firmware"
    
    # Create directory if it doesn't exist
    mkdir -p "$WINE_FIRMWARE_DIR"
    
    # Copy firmware files
    cp "$FIRMWARE_EXE" "$WINE_FIRMWARE_DIR/" || error_exit "Failed to copy firmware executable"
    cp "$FIRMWARE_FILE" "$WINE_FIRMWARE_DIR/" || error_exit "Failed to copy firmware file"
    cp "$FIRMWARE_DIR/python27.dll" "$WINE_FIRMWARE_DIR/" || warning_msg "Failed to copy python27.dll"
    
    # Get Windows-style paths
    WINE_FIRMWARE_EXE="C:\\Cherry_Firmware\\$(basename "$FIRMWARE_EXE")"
    WINE_FIRMWARE_FILE="C:\\Cherry_Firmware\\$(basename "$FIRMWARE_FILE")"
    
    # Run the firmware update executable
    echo "Running firmware update (this may take a few minutes)..."
    log_verbose "Running firmware update..."
    
    # Create a temporary file to capture Wine output
    WINE_OUTPUT=$(mktemp)
    
    # If debug mode is enabled, show more information
    if [ "$DEBUG_MODE" = true ]; then
        echo "Debug mode enabled. Showing USB devices:"
        system_profiler SPUSBDataType | grep -A 10 Cherry
        echo "Smart card status:"
        system_profiler SPSmartCardsDataType
        echo "Wine USB devices:"
        WINEDEBUG=+usb wine cmd /c "echo Checking USB devices" 2>&1 | grep -i usb
    fi
    
    # Try different approaches to run the firmware update
    log_verbose "Attempting firmware update with standard parameters..."
    
    # First attempt: Using -r parameter as shown in the batch files
    if [ "$DEBUG_MODE" = true ]; then
        echo "Attempt 1: Using -r parameter with reader name"
        WINEDEBUG=+usb,+relay wine "$WINE_FIRMWARE_EXE" -r "Cherry KC 1000 SC 0" "$WINE_FIRMWARE_FILE" | tee "$WINE_OUTPUT" || true
    elif [ "$QUIET_MODE" = true ]; then
        wine "$WINE_FIRMWARE_EXE" -r "Cherry KC 1000 SC 0" "$WINE_FIRMWARE_FILE" > "$WINE_OUTPUT" 2>&1 || true
    else
        wine "$WINE_FIRMWARE_EXE" -r "Cherry KC 1000 SC 0" "$WINE_FIRMWARE_FILE" | tee "$WINE_OUTPUT" || true
    fi
    
    # Check if the update failed with the reader error
    if grep -i "Can not connect to the reader" "$WINE_OUTPUT" > /dev/null; then
        warning_msg "First attempt failed with 'Can not connect to the reader' error."
        info_msg "Trying alternative approach..."
        
        # Second attempt: Try with -r parameter and -force option
        if [ "$DEBUG_MODE" = true ]; then
            echo "Attempt 2: Using -r parameter with -force option"
            WINEDEBUG=+usb,+relay wine "$WINE_FIRMWARE_EXE" -r "Cherry KC 1000 SC 0" -force "$WINE_FIRMWARE_FILE" | tee "$WINE_OUTPUT" || true
        elif [ "$QUIET_MODE" = true ]; then
            wine "$WINE_FIRMWARE_EXE" -r "Cherry KC 1000 SC 0" -force "$WINE_FIRMWARE_FILE" > "$WINE_OUTPUT" 2>&1 || true
        else
            wine "$WINE_FIRMWARE_EXE" -r "Cherry KC 1000 SC 0" -force "$WINE_FIRMWARE_FILE" | tee "$WINE_OUTPUT" || true
        fi
        
        # Check if the second attempt also failed
        if grep -i "Can not connect to the reader" "$WINE_OUTPUT" > /dev/null; then
            warning_msg "Second attempt also failed with 'Can not connect to the reader' error."
            info_msg "Trying with batch file approach..."
            
            # Create a batch file to run the firmware update with -r parameter
            BAT_FILE="$WINE_FIRMWARE_DIR/update_firmware.bat"
            cat > "$BAT_FILE" << EOF
@echo off
echo Running Cherry KC 1000 SC Firmware Update...
"$(basename "$FIRMWARE_EXE")" -r "Cherry KC 1000 SC 0" "$(basename "$FIRMWARE_FILE")"
EOF
            
            # Run the batch file
            if [ "$DEBUG_MODE" = true ]; then
                echo "Attempt 3: Using batch file approach"
                WINEDEBUG=+usb,+relay wine cmd /c "C:\\Cherry_Firmware\\update_firmware.bat" | tee "$WINE_OUTPUT" || true
            elif [ "$QUIET_MODE" = true ]; then
                wine cmd /c "C:\\Cherry_Firmware\\update_firmware.bat" > "$WINE_OUTPUT" 2>&1 || true
            else
                wine cmd /c "C:\\Cherry_Firmware\\update_firmware.bat" | tee "$WINE_OUTPUT" || true
            fi
            
            # If all attempts failed, try with different reader name formats
            if grep -i "Can not connect to the reader" "$WINE_OUTPUT" > /dev/null; then
                warning_msg "Third attempt also failed with 'Can not connect to the reader' error."
                info_msg "Trying with alternative reader name formats..."
                
                # Try with different reader name formats
                READER_NAMES=("Cherry KC 1000 SC" "Cherry KC 1000" "Cherry KC1000SC" "Cherry")
                
                for reader in "${READER_NAMES[@]}"; do
                    if [ "$DEBUG_MODE" = true ]; then
                        echo "Trying with reader name: $reader"
                        WINEDEBUG=+usb,+relay wine "$WINE_FIRMWARE_EXE" -r "$reader" "$WINE_FIRMWARE_FILE" | tee "$WINE_OUTPUT" || true
                    elif [ "$QUIET_MODE" = true ]; then
                        wine "$WINE_FIRMWARE_EXE" -r "$reader" "$WINE_FIRMWARE_FILE" > "$WINE_OUTPUT" 2>&1 || true
                    else
                        wine "$WINE_FIRMWARE_EXE" -r "$reader" "$WINE_FIRMWARE_FILE" | tee "$WINE_OUTPUT" || true
                    fi
                    
                    # If this attempt succeeded, break the loop
                    if ! grep -i "Can not connect to the reader" "$WINE_OUTPUT" > /dev/null; then
                        success_msg "Successfully connected to reader with name: $reader"
                        break
                    fi
                done
            fi
        fi
    fi
    
    # Check if the firmware update was successful
    if [ $? -eq 0 ] && ! grep -i "Can not connect to the reader" "$WINE_OUTPUT" > /dev/null; then
        # Clean up temporary file
        rm -f "$WINE_OUTPUT"
        
        success_msg "Firmware update completed successfully!"
        success_msg "Please unplug your keyboard and plug it back in to apply the changes."
    else
        # Clean up temporary file
        rm -f "$WINE_OUTPUT"
        
        warning_msg "Firmware update may not have completed successfully."
        warning_msg "If you encountered any errors, please try the following:"
        echo "1. Insert a readable smart card into the keyboard's card reader"
        echo "2. Disconnect and reconnect your keyboard"
        echo "3. Try a different USB port"
        echo "4. Restart your Mac and try again"
        echo "5. Make sure no other applications are using the keyboard"
    fi
}

# Main script execution
# Create log file or clear existing one
echo "$(date): Cherry KC 1000 SC Firmware Update Tool started" > "$LOG_FILE"
log_verbose "Script version: 1.0.5"
log_verbose "Script date: June 2, 2025"
log_verbose "Working directory: $SCRIPT_DIR"

if [ "$UNINSTALL_MODE" = true ]; then
    # Run uninstallation
    uninstall_components
else
    # Normal installation and update mode
    if [ "$QUIET_MODE" = false ]; then
        echo "========================================================"
        echo "  Cherry KC 1000 SC Firmware Update Tool for macOS"
        echo "========================================================"
        echo
        echo "Detailed logs are being written to: $LOG_FILE"
        echo
    fi
    
    # Check for required files
    check_required_files
    
    # Install dependencies
    install_homebrew
    install_xquartz
    install_wine
    
    # Configure Wine
    configure_wine
    
    # Check if keyboard is connected
    check_keyboard_connected
    
    # Run firmware update
    run_firmware_update
    
    # Reset Wine prefix
    unset WINEPREFIX
    
    echo
    success_msg "Script completed."
    if [ "$QUIET_MODE" = false ]; then
        echo "If you have any issues, please refer to the README.md file for troubleshooting tips."
        echo "Detailed logs are available at: $LOG_FILE"
        echo "========================================================"
    fi
fi

exit 0
