# Lenovo Software Update Script

## Overview

This PowerShell script automates the management of Lenovo software updates on your Windows computer. It also provides robust logging capabilities to help you keep track of the update process and any potential issues.

## Features

- Checks for administrator privileges and prompts the user to run the script as an administrator if necessary.
- Installs the `LSUClient` module if it's not already installed.
- Installs or updates the NuGet provider to ensure compatibility with package management.
- Installs unattended Lenovo updates.
- Installs interactive Lenovo updates (requires user interaction).
- Checks for a reboot requirement and allows the user to initiate a reboot if necessary.
- Maintains a structured log file with timestamped entries and log rotation.

## Prerequisites

- PowerShell (Version 5.1 or later recommended)
- Administrator privileges for script execution

## Usage

1. Open PowerShell with administrator privileges.

2. Navigate to the directory containing the script.

3. Run the script using the following command:

   ```powershell
   .\Lenovo-SoftwareUpdate.ps1
Follow the on-screen prompts and instructions as needed.
Logging
Log files are stored in the Logs directory within your user's Documents folder.
Logs are timestamped and color-coded (INFO in yellow, ERROR in red) for easy readability.
Log rotation ensures log files do not exceed a defined maximum size (100MB by default).
Author
Author: Calvin Quint
Contact Email: github@myqnet.io
GitHub Repository: https://github.com/calvin-quint/Lenovo-SoftwareUpdate
License
This script is released under the GNU General Public License (GPL).

Notes
Please ensure that you have appropriate backups and safeguards in place before running any script that modifies your system.
If you encounter issues or have questions, feel free to contact the author via the provided email address.
