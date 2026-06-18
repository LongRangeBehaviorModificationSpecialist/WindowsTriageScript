<#
    File:        Run-Triage.ps1
    Purpose:     Automated launcher for the Forensic Triage Suite.
    Usage:       Run from an Elevated PowerShell prompt on the target machine.
    Compiled by: mikespon
    DLU:         31-May-2026
#>

[CmdletBinding()]
param(
    [switch]$gui
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Continue

# Dynamically find the USB drive root directory (avoids hardcoding drive letters)
$usb_directory = $PSScriptRoot


# FORCE the path to convert to an absolute path string (Resolves any .\ or broken slashes)
$manifest_path = [System.IO.Path]::GetFullPath($(Join-Path -Path $usb_directory -ChildPath "modules\triage.psd1"))

# Import the Master Manifest Module
if (Test-Path -Path $manifest_path) {
    Write-Host "`n[-] Loading forensic modules..." -ForegroundColor Cyan
    Import-Module -Name $manifest_path -Force
    Write-Host "[+] Module file: `"$(Split-Path $manifest_path -Leaf)`" was imported successfully." -ForegroundColor Green
    Write-Host "[+] Triage Suite loaded successfully!`n" -ForegroundColor Green
}
else {
    Write-Error "[!] CRITICAL FILE ERROR: Cannot find the triage manifest at `"$($manifest_path)`"."
    Exit
}

# Check for Administrator Rights
# Volatile collection (Network, RAM, Handles) will fail silently without this.
$is_admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $is_admin) {
    Write-Error "[!] CRITICAL ACCESS ERROR: This triage tool must be run as Administrator."
    Write-Host "[!] Please close this window, open PowerShell as Administrator, and try again." -ForegroundColor Yellow
    Exit
}

$run_date      = Get-Date -Format yyyyMMdd_HHmmss
$computer_name = $env:computername
$ipv4          = (Test-Connection $computer_name -TimeToLive 2 -Count 1).ipv4address | Select-Object -ExpandProperty IPAddressToString

$merged_name = $run_date + "_" + $ipv4 + "_" + $computer_name

$results_folder = Join-Path -Path $usb_directory -ChildPath $merged_name
$null           = New-Item -ItemType Directory -Path $results_folder -Force

$log_folder = Join-Path -Path $results_folder -ChildPath "Logs"
$null       = New-Item -ItemType Directory -Path $log_folder -Force

$log_file = Join-Path -Path $log_folder -ChildPath "$($merged_name)_Script.log"
$null     = New-Item -ItemType File -Path $log_file -Force


# Stops the script until the user presses the ENTER key so the script does not begin before the user is ready
Read-Host -Prompt "`nPress [ENTER] to begin Volatile and System Data collection"


if ($gui) {
    Get-Gui
}
else {
    Invoke-DfirTriageScan -ResultsFolder $results_folder
}
