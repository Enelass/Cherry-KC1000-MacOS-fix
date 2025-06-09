# Cherry KC 1000 SC Firmware Update using QEMU (Tested)

This folder contains scripts and instructions for updating the Cherry KC 1000 SC keyboard firmware using QEMU virtualization on macOS.

## Testing Results

We've tested the QEMU-based approach and confirmed:

1. ✅ QEMU can be successfully installed on macOS using Homebrew
2. ✅ The Cherry KC 1000 SC keyboard can be detected with Vendor ID: 046a, Product ID: 00a1
3. ✅ QEMU can be configured for USB passthrough with the detected keyboard
4. ⚠️ USB passthrough requires special permissions on macOS (may need to run with sudo)
5. ⚠️ You need to set `export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` to avoid Objective-C runtime issues

## Why QEMU?

QEMU is a powerful open-source machine emulator and virtualizer that allows running Windows on macOS without requiring a commercial virtualization solution. For the Cherry KC 1000 SC firmware update, QEMU offers several advantages:

1. **Free and open-source**: No commercial licenses required
2. **USB passthrough support**: Properly handles USB devices, unlike Wine
3. **Lightweight**: More efficient than full commercial VM solutions
4. **Scriptable**: Can be automated for a smoother user experience

## Prerequisites

- macOS 10.15 or later
- Homebrew package manager
- At least 4GB of free disk space
- A Windows 10 ISO file (for the VM)
- Internet connection (for downloading dependencies)
- Cherry KC 1000 SC keyboard
- Administrator privileges (for USB access)

## Files in this Directory

- `setup_qemu.sh`: Script to install QEMU and its dependencies
- `run_windows_vm.sh`: Script to create and run a Windows VM with USB passthrough
- `update_firmware.sh`: Main script that orchestrates the entire firmware update process
- `config/`: Directory containing QEMU configuration files
  - `vm_config.conf`: Configuration settings for the VM
  - `usb_passthrough.sh`: Helper script for USB device detection and passthrough

## Installation and Usage

1. Make the scripts executable:
   ```bash
   chmod +x QEMU/*.sh QEMU/config/*.sh
   ```

2. Run the setup script to install QEMU and dependencies:
   ```bash
   ./QEMU/setup_qemu.sh
   ```

3. Run the main script with a path to a Windows ISO:
   ```bash
   ./QEMU/update_firmware.sh --windows /path/to/windows.iso
   ```

4. Follow the on-screen instructions to:
   - Set up a minimal Windows VM
   - Pass through the Cherry keyboard to the VM
   - Run the firmware update tool in the VM

## How It Works

The solution uses QEMU's USB passthrough feature to make the Cherry keyboard directly accessible to a Windows virtual machine. The process is:

1. **Setup**: Install QEMU and dependencies
2. **Keyboard Detection**: Automatically detect the Cherry KC 1000 SC keyboard (Vendor ID: 046a, Product ID: 00a1)
3. **VM Creation**: Create a minimal Windows VM configured for the firmware update
4. **USB Passthrough**: Configure QEMU to pass the Cherry keyboard through to the VM
5. **Firmware Update**: Run the Cherry firmware update tool within the VM
6. **Cleanup**: Optionally remove the VM after the update is complete

## macOS-Specific Considerations

When running QEMU on macOS, you need to be aware of these specific issues:

1. **USB Access Permissions**: macOS restricts direct access to USB devices. You may need to run the script with sudo or grant special permissions.

2. **Objective-C Runtime Issues**: Set this environment variable before running QEMU:
   ```bash
   export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
   ```

3. **VirtIO Drivers**: The script attempts to download VirtIO drivers, but if this fails, you can manually download them from the Fedora project website.

## Troubleshooting

- **USB device not detected**: Make sure the keyboard is connected before starting the VM
- **QEMU installation issues**: Try installing QEMU manually with `brew install qemu`
- **Windows VM boot problems**: Verify the Windows ISO file is valid
- **USB passthrough not working**: Try running the script with sudo for proper USB access
- **Objective-C errors**: Make sure to set the OBJC_DISABLE_INITIALIZE_FORK_SAFETY environment variable

## Uninstallation

To remove all components installed by the script:

```bash
./QEMU/update_firmware.sh --uninstall
```

This will:
1. Remove the Windows VM image
2. Uninstall QEMU and its dependencies
3. Clean up any temporary files

## License

This project is licensed under the MIT License - see the LICENSE file in the root directory for details.