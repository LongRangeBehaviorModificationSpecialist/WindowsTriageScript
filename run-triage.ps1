<#
    File         :  Run-Triage.ps1
    Purpose      :  Automated launcher for the Forensic Triage Suite.
    Usage        :  Run from an Elevated PowerShell prompt on the target
                    machine.
    Compiled by  :  mikespon
    DLU          :  31-May-2026
#>

[CmdletBinding()]

param(
    [switch]$Gui
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Continue

# Dynamically find the USB drive root directory (avoids hardcoding drive
# letters)
$UsbDirectory = $PSScriptRoot

$FunctionsModule = [System.IO.Path]::GetFullPath($(Join-Path -Path $UsbDirectory -ChildPath "modules\functions.psm1"))
Import-Module -Name $FunctionsModule -Force

# FORCE the path to convert to an absolute path string (Resolves any .\ or
# broken slashes)
$ManifestPath = [System.IO.Path]::GetFullPath($(Join-Path -Path $UsbDirectory -ChildPath "modules\triage.psd1"))

# Import the Master Manifest Module
if (Test-Path -Path $ManifestPath) {
    Show-Message "Loading forensic modules..." -AddToLog
    Import-Module -Name $ManifestPath -Force
    Show-Message "Module file: '$( Split-Path $ManifestPath -Leaf )' was imported successfully" -AddToLog
    Show-Message "Triage Suite loaded successfully!" -MessageColor Green -AddToLog
}
else {
    Show-Message "CRITICAL FILE ERROR: Cannot find the triage manifest at '$ManifestPath'." -Level ERROR -AddToLog
    Exit
}

# Check for Administrator Rights
# Volatile collection (Network, RAM, Handles) will fail silently without this.
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($IsAdmin) {
    Show-Message "Program running as Administrator..." -MessageColor Green
}
else {
    Show-Message "CRITICAL ACCESS ERROR: This triage tool must be run as Administrator." -Level ERROR
    Show-Message "Please close this window, open PowerShell as Administrator, and try again." -Level WARNING
    Exit
}

# $RunDate        = Get-Date -Format yyyyMMdd_HHmmss
# $ComputerName   = $env:computername
# $Ipv4           = (Test-Connection $ComputerName -TimeToLive 2 -Count 1).ipv4address | Select-Object -ExpandProperty IPAddressToString

# $MergedName     = $RunDate + "_" + $Ipv4 + "_" + $ComputerName

# $ResultsFolder  = Join-Path -Path $UsbDirectory -ChildPath $MergedName
# $null           = New-Item -ItemType Directory -Path $ResultsFolder -Force

# $LogFolder      = Join-Path -Path $ResultsFolder -ChildPath "Logs"
# $null           = New-Item -ItemType Directory -Path $LogFolder -Force

# $LogFile        = Join-Path -Path $LogFolder -ChildPath "$($MergedName)_Script.log"
# $null           = New-Item -ItemType File -Path $LogFile -Force


if ($Gui) {
    Get-Gui
}
else {
    Get-InitialSetup
    Show-Message "The results of this scan will be saved in the '$( $ResultsFolder )' folder"
    Show-Message "Log file = $( $LogFile )"
    # Stops the script until the user presses the ENTER key so the script does not begin before the user is ready
    Read-LogHost -Prompt "Press [ENTER] to begin Volatile and System Data collection" -PromptColor Yellow
    Invoke-DfirTriageScan -ResultsFolder $ResultsFolder
}
