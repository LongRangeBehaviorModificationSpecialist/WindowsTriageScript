<#
    File         :  Run-Triage.ps1
    Purpose      :  Automated launcher for the Forensic Triage Suite.
    Usage        :  Run from an Elevated PowerShell prompt on the target machine.
    Compiled by  :  mikespon
    DLU          :  31-May-2026
#>

[CmdletBinding()]
param(
    [switch]$Gui
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Continue

# Dynamically find the USB drive root directory (avoids hardcoding drive letters)
$UsbDirectory = $PSScriptRoot


# FORCE the path to convert to an absolute path string (Resolves any .\ or broken slashes)
$ManifestPath = [System.IO.Path]::GetFullPath($(Join-Path -Path $UsbDirectory -ChildPath "modules\triage.psd1"))

# Import the Master Manifest Module
if (Test-Path -Path $ManifestPath) {
    Write-Host "`n[-] Loading forensic modules..." -ForegroundColor Cyan
    Import-Module -Name $ManifestPath -Force
    Write-Host "[+] Module file: `"$( Split-Path $ManifestPath -Leaf )`" was imported successfully." -ForegroundColor Green
    Write-Host "[+] Triage Suite loaded successfully!`n" -ForegroundColor Green
}
else {
    Write-Error "[!] CRITICAL FILE ERROR: Cannot find the triage manifest at `"$( $ManifestPath )`"."
    Exit
}

# Check for Administrator Rights
# Volatile collection (Network, RAM, Handles) will fail silently without this.
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Error "[!] CRITICAL ACCESS ERROR: This triage tool must be run as Administrator."
    Write-Host "[!] Please close this window, open PowerShell as Administrator, and try again." -ForegroundColor Yellow
    Exit
}

$RunDate        = Get-Date -Format yyyyMMdd_HHmmss
$ComputerName   = $env:computername
$Ipv4           = (Test-Connection $ComputerName -TimeToLive 2 -Count 1).ipv4address | Select-Object -ExpandProperty IPAddressToString

$MergedName     = $RunDate + "_" + $Ipv4 + "_" + $ComputerName

$ResultsFolder  = Join-Path -Path $UsbDirectory -ChildPath $MergeNname
$null           = New-Item -ItemType Directory -Path $ResultsFolder -Force

$LogFolder      = Join-Path -Path $ResultsFolder -ChildPath "Logs"
$null           = New-Item -ItemType Directory -Path $LogFolder -Force

$LogFile        = Join-Path -Path $LogFolder -ChildPath "$( $MergedName )_Script.log"
$null           = New-Item -ItemType File -Path $LogFile -Force


# Stops the script until the user presses the ENTER key so the script does not begin before the user is ready
Read-Host -Prompt "`nPress [ENTER] to begin Volatile and System Data collection"


if ($gui) {
    Get-Gui
}
else {
    Invoke-DfirTriageScan -ResultsFolder $ResultsFolder
}
