<#
.SYNOPSIS
    The Lenovo Software Update Script is a PowerShell tool that automates Lenovo software updates, ensuring system health and user experience by managing unattended and interactive 
     updates while maintaining comprehensive logs and administrative privileges.
    
.DESCRIPTION
    The Lenovo Software Update Script streamlines the management of Lenovo software updates, optimizing system performance and user satisfaction. This PowerShell tool facilitates
    the installation of both unattended and interactive updates, providing flexibility to accommodate various user scenarios. It also offers robust logging capabilities, ensuring transparency
    in update processes, and checks for administrative privileges to guarantee successful execution.
    
.NOTES
    File Name      : Lenovo_Updates.ps1
    Author         : Calvin Quint
    Prerequisite   : LSUClient module, Package Provider NuGet version 2.8.5.201
    License        : GNU GPL
    
.LINK
    GitHub Repository: https://github.com/calvin-quint/Lenovo_Updates
    
.EMAIL
    Contact email: github@myqnet.io
    
#>

function Test-OneDrive {
    if ($env:OneDrive -ne $null -and $env:OneDrive -ne "") {
        return $true
    } else {
        return $false
    }
}

# Function that determines the appropriate directory path for storing log files based on the presence of OneDrive. 
# It returns the path to the log directory within the user's Documents folder, accounting for OneDrive if it is available, 
# simplifying log file management in PowerShell scripts.
function Get-LogDirectory {
    if (Test-OneDrive) {
        return "$env:OneDrive\Documents\Scripts\Powershell\Logs"
    } else {
        return "$env:USERPROFILE\Documents\Scripts\Powershell\Logs"
    }
}

# Function that ensures the existence of a specified directory and log file, creating them if they don't exist. It provides error handling and logging, 
# making it a valuable utility for maintaining a structured logging environment in PowerShell scripts.
function Ensure-DirectoryAndLogFile {
    param (
        [string]$directoryPath,
        [string]$logFilePath
    )

    if (-not (Test-Path -Path $directoryPath -PathType Container)) {
        try {
            New-Item -Path $directoryPath -ItemType Directory -Force
            Write-Log "Directory created: $($directoryPath)" "INFO"
        } catch {
            Write-Host "Failed to create directory: $($directoryPath)"
            Write-Host "Error: $_"
            exit 1
        }
    }

    if (-not (Test-Path -Path $logFilePath)) {
        try {
            $null | Out-File -FilePath $logFilePath -Force
            Write-Log "Log file created: $logFilePath" "INFO"
        } catch {
            Write-Host "Failed to create log file: $logFilePath"
            Write-Host "Error: $_"
            exit 1
        }
    }
}

# Function that records log messages with timestamps and color-coded levels (INFO in Yellow and ERROR in Red), displaying them in the console and appending them to a log file. 
# It also manages log file size by performing log rotation when it exceeds a defined limit, ensuring effective logging and file management in PowerShell scripts.
function Write-Log {
    param(
        [string]$message,
        [string]$level
    )

    $logDirectory = Get-LogDirectory
    $logFilePath = "$logDirectory\LenovoUpdates_Log.txt"

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$level] $message"

    # Define colors for INFO and ERROR log levels
    $infoColor = "Yellow"
    $errorColor = "Red"

    # Display the log message in the console with the appropriate color
    if ($level -eq "INFO") {
        Write-Host $logMessage -ForegroundColor $infoColor
    } elseif ($level -eq "ERROR") {
        Write-Host $logMessage -ForegroundColor $errorColor
    } else {
        Write-Host $logMessage
    }

    # Ensure the log directory and log file exist using the combined function
    Ensure-DirectoryAndLogFile -directoryPath $logDirectory -logFilePath $logFilePath

    # Append the log message to the log file
    $logMessage | Out-File -FilePath $logFilePath -Append

    # Get the current log file size
    $currentFileSize = (Get-Item $logFilePath).Length

    # Define the maximum log file size (100MB)
    $maxLogSize = 100MB

    # If the current log file size exceeds the maximum, perform log rotation
    if ($currentFileSize -gt $maxLogSize) {
        $linesToKeep = 500  # Define the maximum number of log lines to keep
        $logContent = Get-Content -Path $logFilePath -TotalCount $linesToKeep
        $logContent | Out-File -FilePath $logFilePath -Force
    }
}

function Install-AndImportModule {
    param(
        [string]$moduleName,
        [string]$moduleCheckCommand
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Log "This script requires administrator rights to install the $moduleName module. Please run the script as an administrator." "ERROR"
        exit
    }

    if (-not (Get-Module -Name $moduleName -ListAvailable)) {
        Write-Log "Installing $moduleName module..." "INFO"
        Install-Module -Name $moduleName -Force
    }

    Import-Module $moduleName -ErrorAction Stop
}


function Install-AndImportPackageProvider {
    param (
        [string]$providerName,
        [string]$minimumVersion
    )

    $currentProvider = Get-PackageProvider -Name $providerName -ErrorAction SilentlyContinue

    if (!$currentProvider) {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin) {
            Write-Log "This script requires administrator rights to install the $providerName provider. Please run the script as an administrator." "ERROR"
            exit
        }

        Write-Log "Installing $providerName provider version $minimumVersion..." "INFO"
        Install-PackageProvider -Name $providerName -Force -MinimumVersion $minimumVersion
        Write-Log "$providerName provider version $minimumVersion installed." "INFO"
    } else {
        if ([Version]$currentProvider.Version -lt [Version]$minimumVersion) {
            Write-Log "Updating $providerName provider to version $minimumVersion..." "INFO"
            Uninstall-PackageProvider -Name $providerName -Force
            Install-PackageProvider -Name $providerName -Force -MinimumVersion $minimumVersion
            Write-Log "$providerName provider updated to version $minimumVersion." "INFO"
        } else {
            Write-Log "$providerName provider is up to date." "INFO"
        }
    }
}

# Function to install updates that require user interaction
function Install-InteractiveUpdates {
    $updates = Get-LSUpdate | Where-Object { $_.Installer.Unattended -eq $false }

    if ($updates.Count -eq 0) {
        Write-Log "No Lenovo updates requiring user interaction available." "INFO"
    } else {
        Write-Log "Installing Lenovo updates requiring user interaction..." "INFO"
        $updates | ForEach-Object {
            Write-Log "Installing Lenovo update: $($_.Title)" "INFO"
            Install-LSUpdate $_ -Verbose
            Write-Log "Update installed: $($_.Title)" "INFO"
        }
        Write-Log "All Lenovo updates requiring user interaction installed." "INFO"
    }
}

# Function to install updates that do not require user interaction
function Install-UnattendedUpdates {
    $updates = Get-LSUpdate | Where-Object { $_.Installer.Unattended -eq $true }

    if ($updates.Count -eq 0) {
        Write-Log "No unattended Lenovo updates available." "INFO"
    } else {
        Write-Log "Installing unattended Lenovo updates..." "INFO"
        $updates | ForEach-Object {
            Write-Log "Installing unattended update: $($_.Title)" "INFO"
            Install-LSUpdate $_ -Verbose
            Write-Log "Update installed: $($_.Title)" "INFO"
        }
        Write-Log "All unattended Lenovo updates installed." "INFO"
    }
}

# Function to test if there is an interactive user
function Test-InteractiveUser {
    $tsProperty = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.IsTokenFromRemoteSession
    return -not $tsProperty
}

function Check-RebootRequired {
    param (
        [bool]$rebootRequired
    )

    if ($rebootRequired) {
        $rebootUpdates = Get-LSUpdate | Where-Object { $_.RequiresReboot }
        if ($rebootUpdates) {
            do {
                $restartOption = Read-Host "Lenovo updates have been installed and a reboot is required. Do you want to restart your computer? (Y/N)"
            } while ($restartOption -ne 'Y' -and $restartOption -ne 'N' -and $restartOption -ne 'y' -and $restartOption -ne 'n')

            if ($restartOption -eq 'Y' -or $restartOption -eq 'y') {
                Write-Log "Restarting computer..." "INFO"
                Restart-Computer -Force
            } else {
                Write-Log "No restart requested." "INFO"
            }
        } else {
            Write-Log "No updates requiring reboot installed." "INFO"
        }
    } else {
        Write-Log "No interactive user detected. Rebooting computer..." "INFO"
        Restart-Computer -Force
    }
}

function Main {
    Write-Log "Starting script execution." "INFO"

    # Step 1: Install and import required module if needed
    Install-AndImportModule -moduleName "LSUClient" -moduleCheckCommand "Get-Module -Name LSUClient -ListAvailable"

    $nugetVersionRequired = '2.8.5.201'

    # Step 2: Install NuGet provider if needed
    Install-AndImportPackageProvider -providerName 'NuGet' -minimumVersion $nugetVersionRequired

    # Step 3: Install unattended updates
    Install-UnattendedUpdates

    # Step 4: Test for interactive user
    $isInteractiveUser = Test-InteractiveUser

    # Step 5: Install interactive updates if there is a user
    if ($isInteractiveUser) {
        Install-InteractiveUpdates
    }

    # Step 6: Test for and reboot if required
    if (Check-RebootRequired) {
        Write-Log "Reboot is required. Initiating reboot." "INFO"
        Restart-Computer -Force
    }

    Write-Log "Script execution completed." "INFO"
}

# Execute the main script
Main | Out-Null
