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
$usbDirectory = $PSScriptRoot


# FORCE the path to convert to an absolute path string (Resolves any .\ or broken slashes)
$manifestPath = [System.IO.Path]::GetFullPath($(Join-Path -Path $usbDirectory -ChildPath "modules\triage.psd1"))

# Import the Master Manifest Module
if (Test-Path -Path $manifestPath) {
    Write-Host "`n[-] Loading forensic modules..." -ForegroundColor Cyan
    Import-Module -Name $manifestPath -Force
    Write-Host "[+] Module file: '$(Split-Path $manifestPath -Leaf)' was imported successfully." -ForegroundColor Green
    Write-Host "[+] Triage Suite loaded successfully!`n" -ForegroundColor Green
}
else {
    Write-Error "[!] CRITICAL FILE ERROR: Cannot find the triage manifest at '$manifestPath'."
    Exit
}

# Check for Administrator Rights
# Volatile collection (Network, RAM, Handles) will fail silently without this.
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Error "[!] CRITICAL ACCESS ERROR: This triage tool must be run as Administrator."
    Write-Host "[!] Please close this window, open PowerShell as Administrator, and try again." -ForegroundColor Yellow
    Exit
}

$runDate = Get-Date -Format yyyyMMdd_HHmmss
$computerName = $env:computername
$ipv4 = (Test-Connection $computerName -TimeToLive 2 -Count 1).ipv4address | Select-Object -ExpandProperty IPAddressToString

$mergedName = $runDate + "_" + $ipv4 + "_" + $computerName

$resultsFolder = Join-Path -Path $usbDirectory -ChildPath $mergedName
$null = New-Item -ItemType Directory -Path $resultsFolder -Force

$logFolder = Join-Path -Path $resultsFolder -ChildPath "Logs"
$null = New-Item -ItemType Directory -Path $logFolder -Force

$logFile = Join-Path -Path $logFolder -ChildPath "${mergedName}_Script.log"
$null = New-Item -ItemType File -Path $logFile -Force


# Stops the script until the user presses the ENTER key so the script does not begin before the user is ready
Read-Host -Prompt "`nPress [ENTER] to begin Volatile and System Data collection"


if ($gui) {
    Get-Gui
}
else {
    Invoke-DfirTriageScan -ResultsFolder $resultsFolder
}
