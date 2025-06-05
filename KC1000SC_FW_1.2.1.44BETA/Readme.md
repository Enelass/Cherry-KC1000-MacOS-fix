# Cherry KC 1000 SC Firmware Update

## Firmware Version: 1.2.1.44 BETA

This firmware update resolves issues with keystrokes being ignored or repeated on macOS systems.

## Original Windows Requirements (For Reference)
- Windows 10 64-bit
- KC1000SC Driver 1.0.5.xxx installed on system
- If driver is not available, a readable Smartcard must be inserted when starting the update

## macOS Update Process (Using Wine)
The `update_cherry_firmware.sh` script in the parent directory handles all the necessary steps to update your keyboard's firmware on macOS:

1. Plug in your Cherry KC 1000 SC keyboard
2. Run the script: `./update_cherry_firmware.sh`
3. Follow the on-screen instructions
4. When the update completes, unplug and reconnect your keyboard

## Files in this Directory

- `boot4_upload.exe` - The firmware update executable (Windows)
- `CHKBD-1.2.1.44-20250324T205718-1DF21CCF5F7E-RELEASE.sfu` - The firmware file
- `python27.dll` - Required DLL for the update executable
- `read_firmware_version.bat` - Batch file to check current firmware version (Windows only)
- `Start_firmware_uploadl_1_2_1_44.bat` - Original Windows batch file to start the update

## Troubleshooting

If you encounter issues with the firmware update:

1. Make sure your keyboard is properly connected
2. Try a different USB port
3. Restart your Mac and try again
4. Check the main README.md file for detailed troubleshooting steps

## After the Update

After successfully updating the firmware:

1. Unplug your keyboard
2. Wait a few seconds
3. Reconnect your keyboard
4. Test to ensure the keystroke issues are resolved
