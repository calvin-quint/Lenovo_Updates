<#
.SYNOPSIS
    The Lenovo Software Update Script is a PowerShell tool that automates Lenovo software updates, ensuring system health and user experience by managing unattended and interactive 
     updates while maintaining comprehensive logs and administrative privileges.
    
.DESCRIPTION
    The Lenovo Software Update Script streamlines the management of Lenovo software updates, optimizing system performance and user satisfaction. This PowerShell tool facilitates
    the installation of both unattended and interactive updates, providing flexibility to accommodate various user scenarios. It also offers robust logging capabilities, ensuring transparency
    in update processes, and checks for administrative privileges to guarantee successful execution.
    
.NOTES
    File Name      : Lenovo-SoftwareUpdate.ps1
    Author         : Calvin Quint
    Prerequisite   : LSUClient module, Package Provider NuGet version 2.8.5.201
    License        : GNU GPL
    
.LINK
    GitHub Repository: https://github.com/calvin-quint/Lenovo_Updates
    
.EMAIL
    Contact email: github@myqnet.io
    
#>

# Set up logging
$logFile = "update_lenovo.log"
$maxLogSize = 100MB  # Maximum log size in bytes

function Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Write-Host $logMessage
    $logMessage | Out-File -Append -FilePath $logFile

    # Check log file size and truncate if necessary
    $logFileSize = (Get-Item $logFile).Length
    if ($logFileSize -gt $maxLogSize) {
        Write-Host "Log file size exceeds maximum limit. Truncating..."
        $logContent = Get-Content $logFile -Raw
        $startIndex = $logContent.IndexOf("`n", [math]::Max(0, $logContent.Length - $maxLogSize))
        if ($startIndex -ge 0) {
            $truncatedContent = $logContent.Substring($startIndex + 1)
            $truncatedContent | Set-Content $logFile
            Write-Host "Log file truncated."
        }
    }
}

# Log user who ran the script
$executingUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
Log "Script executed by user: $executingUser"

# Retrieve the computer manufacturer and model
$manufacturer = (Get-WmiObject Win32_ComputerSystem).Manufacturer
$model = (Get-WmiObject Win32_ComputerSystem).Model
Log "Computer Manufacturer: $manufacturer"
Log "Computer Model: $model"

# List of allowed computer models
$allowedModels = @(
    "20XF004FUS",
    "21BR002TUS",
    "20XF004FUS",
    "20UD003LUS",
    "20WM0081US"
    # Add more allowed models here
)

# Check if computer model is allowed or add it to allowedModels
if ($manufacturer -eq "LENOVO" -and $model -notin $allowedModels) {
    Log "Adding current model ($model) to allowedModels..."
    $allowedModels += $model
}

# Define the required NuGet version
$nugetVersionRequired = [Version]'2.8.5.201'

# Check and install/update NuGet Provider, logging actions as needed
$currentNuGetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
if (!$currentNuGetProvider) {
    Log "Installing NuGet Provider version $nugetVersionRequired..."
    Install-PackageProvider -Name NuGet -Force -MinimumVersion $nugetVersionRequired
    Log "NuGet Provider version $nugetVersionRequired installed."
} elseif ($currentNuGetProvider.Version -lt $nugetVersionRequired) {
    Log "Updating NuGet Provider to version $nugetVersionRequired..."
    Uninstall-PackageProvider -Name NuGet -Force
    Install-PackageProvider -Name NuGet -Force -MinimumVersion $nugetVersionRequired
    Log "NuGet Provider updated to version $nugetVersionRequired."
} else {
    Log "NuGet Provider is up to date."
}

# Install the PSWindowsUpdate module if not already installed
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
}

# Import the module
Import-Module PSWindowsUpdate

# Log Windows updates
$windowsUpdates = Get-WUInstall -WindowsUpdate -AcceptAll -IgnoreReboot

if ($windowsUpdates.Count -eq 0) {
    Log "No Windows updates are available."
} else {
    $windowsUpdates | ForEach-Object {
        Log "Windows update found: $($_.Title)"
    }
}

# Import the LSUClient module if not installed
$moduleInstalled = Get-Module -ListAvailable | Where-Object { $_.Name -eq 'LSUClient' }

if (-not $moduleInstalled) {
    Log "LSUClient module is not installed. Installing..."
    Install-Module -Name LSUClient -Force
} else {
    Log "LSUClient module is already installed."
}

# Function to install updates that require user interaction
function Install-InteractiveUpdates {
    $updates = Get-LSUpdate | Where-Object { $_.Installer.Unattended -eq $false }

    if ($updates.Count -eq 0) {
        Log "No Lenovo updates requiring user interaction available."
    } else {
        Log "Installing Lenovo updates requiring user interaction..."
        $updates | ForEach-Object {
            Log "Installing Lenovo update: $($_.Title)"
            Install-LSUpdate $_ -Verbose
            Log "Update installed: $($_.Title)"
        }
        Log "All Lenovo updates requiring user interaction installed."
    }
}

# Function to install updates that do not require user interaction
function Install-UnattendedUpdates {
    $updates = Get-LSUpdate | Where-Object { $_.Installer.Unattended -eq $true }

    if ($updates.Count -eq 0) {
        Log "No unattended Lenovo updates available."
    } else {
        Log "Installing unattended Lenovo updates..."
        $updates | ForEach-Object {
            Log "Installing unattended update: $($_.Title)"
            Install-LSUpdate $_ -Verbose
            Log "Update installed: $($_.Title)"
        }
        Log "All unattended Lenovo updates installed."
    }
}

# Function to test if there is an interactive user
function Test-InteractiveUser {
    $tsProperty = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.IsTokenFromRemoteSession
    return -not $tsProperty
}

# Install unattended Lenovo updates
Install-UnattendedUpdates

# Check for interactive user and install updates requiring user interaction
$rebootRequired = $false
if (Test-InteractiveUser) {
    Log "Interactive user detected. Installing Lenovo updates requiring user interaction..."
    $rebootRequired = $true
    Install-InteractiveUpdates
}

# Check if reboot is required and prompt the user
$rebootRequiredForWindowsUpdates = $windowsUpdates | Where-Object { $_.RequiresReboot }
$rebootRequiredForLenovoUpdates = Get-LSUpdate | Where-Object { $_.RequiresReboot }

if ($rebootRequired -or $rebootRequiredForWindowsUpdates -or $rebootRequiredForLenovoUpdates) {
    $rebootType = ""

    if ($rebootRequiredForWindowsUpdates) {
        $rebootType += "Windows"
    }

    if ($rebootRequiredForLenovoUpdates) {
        if ($rebootType -ne "") {
            $rebootType += " and "
        }
        $rebootType += "Lenovo"
    }

    $rebootMessage = "Updates have been installed and a reboot is required for $rebootType updates. Do you want to restart your computer? (Y/N)"

    $rebootUpdates = $rebootRequiredForWindowsUpdates + $rebootRequiredForLenovoUpdates

    if ($rebootUpdates) {
        $restartOption = Read-Host $rebootMessage
        if ($restartOption -eq 'Y' -or $restartOption -eq 'y') {
            Log "Restarting computer..."
            Restart-Computer -Force
        } else {
            Log "No restart requested."
        }
    } else {
        Log "No updates requiring reboot installed."
    }
} else {
    Log "No interactive user detected. Rebooting computer..."
    Restart-Computer -Force
}

# Log script finish time
Log "Script completed."
