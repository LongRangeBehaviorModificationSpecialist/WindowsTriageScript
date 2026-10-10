<#
.SYNOPSIS
    Launcher for the NOVA ICAC VECTOR Windows triage suite.
.DESCRIPTION
    Can launch the application by using the `.\run-triage.cmd` command and 
    passing the parameters as normal.  This will ensure that the script is run 
    with the `-NoProfile` option.
.PARAMETER Operator
    Examiner name (required unless -Gui).
    Alias: "-Op".
.PARAMETER Agency
    Agency name (optional).
    Alias: "-A".
.PARAMETER CaseNumber
    Case number (required unless -Gui).
    Alias: "-CN".
.PARAMETER CaseFile
    Optional JSON file holding Operator, Agency and CaseNumber, so they stay off
    the command line.
.PARAMETER Modules
    A comma-separated list of module names or 3-digit prefixes, e.g.:
    "001","003","010_Internet".
    Alias: "-Mods".
    Default: "all"
.PARAMETER RunEdd
    Y or N (also Yes/No/True/False/1/0).
    Alias: "-Edd".
    Default: "N"
.PARAMETER CaptureProcesses
    Y or N (also Yes/No/True/False/1/0).
    Alias: "-Proc".
    Default: "N"
.PARAMETER CaptureRam
    Y or N (also Yes/No/True/False/1/0). 
    Alias: "-Ram".
    Default: "N"
.PARAMETER CreateArchive
    Y or N (also Yes/No/True/False/1/0).
    Alias: "-Zip".
    Default: "N"
.PARAMETER OutputRoot
    Folder in which the case folder is created (no trailing backslash).
    Default: the toolkit folder.
.PARAMETER DryRun
    Validate the options, print what would run, and exit without collecting 
    anything.
.EXAMPLE
    .\run-triage.ps1
.EXAMPLE
    run-triage.cmd -DryRun -Operator "MAS" -Agency "Agency" -CaseNumber "12345" -RunEdd Y -CaptureProcesses N -CaptureRam N -CreateArchive N -Modules "001","002","003"
.EXAMPLE
    (Using aliases)
    run-triage.cmd -DryRun -Op "MAS" -A "Agency" -CN "12345" -Edd Y -Proc N -Ram N -Zip N -Modules "001","002","003"
.EXAMPLE
    run-triage.cmd -Operator "MAS" -Agency "Agency" -CaseNumber "12345" -RunEdd Y -CaptureProcesses N -CaptureRam N -CreateArchive N -Modules all
.EXAMPLE
    .\run-triage.ps1 -Operator "J. Smith" -Agency "Example PD" -CaseNumber 2026-0142 -CaptureRam -CreateArchive -Modules ("006_Prefetch", "010_Internet")
.EXAMPLE
    .\run-triage.cmd -GUI
.NOTES
    Exit codes: 0 = completed,
                1 = completed with logged errors,
                2 = could not start (not admin, bad parameters, module load 
                    failed),
                3 = unexpected fatal error.

    Last Updated: 10-Oct-2026
#>

[CmdletBinding()]
param(
    [switch]$Gui,
    [Alias("Op")][string]$Operator,
    [Alias("A")][string]$Agency = "",
    [Alias("CN")][string]$CaseNumber,
    [string]$CaseFile,
    [Alias("Mods")][string[]]$Modules = @("all"),
    [Alias("Edd")][string]$RunEdd = "N",
    [Alias("Proc")][string]$CaptureProcesses = "N",
    [Alias("Ram")][string]$CaptureRam = "N",
    [Alias("Zip")][string]$CreateArchive = "N",
    [string]$OutputRoot,
    [switch]$DryRun
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Continue

$ComputerName = $env:COMPUTERNAME

function ConvertTo-YesNo {
    param([string]$Value)
    switch -Regex ("$Value".Trim()) {
        "^(y|yes|true|1)$" {
            return $true
        }
        "^(n|no|false|0)$" {
            return $false
        }
        default {
            return $null  # For values that are not understood
        }
    }
}

function Show-Usage {
    Write-Host @"

Usage:
    run-triage.cmd -Operator <name> -CaseNumber <number> [options]

Options (Y/N values default to N):
    -Agency <name>          Agency name
    -Modules <list>         all (default) or e.g. 001,003,010_Internet
    -RunEdd Y|N             Encrypted Disk Detector
    -CaptureProcesses Y|N   Magnet Process Capture  (alias: -CaptureProcess)
    -CaptureRam Y|N         Magnet RAM Capture
    -CreateArchive Y|N      Zip the case folder when finished
    -OutputRoot <folder>    Where to create the case folder (no trailing backslash)
    -CaseFile <file.json>   Read Operator, Agency and CaseNumber from a file
    -DryRun                 Check the options and show the plan; collect nothing
    -Gui                    Use the graphical interface

Example:
        run-triage.cmd -Operator "<Name>" -Agency "<Agency>" -CaseNumber "<12345>" -RunEdd <Y/N> -CaptureProcesses <Y/N> -CaptureRam <Y/N> -CreateArchive <Y/N> -Modules [<all>|"001_Device","003_Network"[etc...]]

"@
}

# Load the toolkit and its configuration
try {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath "modules\triage.psd1") -Force -ErrorAction Stop
    $null = Get-TriageConfig
    $AllModules = @(Get-TriageConfig -Key "Modules")
}
catch {
    Write-Host "CRITICAL: cannot load the triage module => $( $_.Exception.Message )" -ForegroundColor Red
    exit 2
}

# Must be elevated (a dry run only checks the options, so it does not need to be)
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin -and -not $DryRun) {
    Show-Message -Message "CRITICAL ACCESS ERROR: This triage tool must be run as Administrator." -Level ERROR
    exit 2
}

# Validate everything and report ALL problems at once
$Problems = [System.Collections.Generic.List[string]]::new()

if ($CaseFile) {
    try {
        $Case = Get-Content -LiteralPath $CaseFile -Raw -ErrorAction Stop | ConvertFrom-Json
        if (-not $PSBoundParameters.ContainsKey("Operator") -and $Case.Operator) {
            $Operator = [string]$Case.Operator
        }
        if (-not $PSBoundParameters.ContainsKey("Agency") -and $Case.Agency) {
            $Agency = [string]$Case.Agency
        }
        if (-not $PSBoundParameters.ContainsKey("CaseNumber") -and $Case.CaseNumber) {
            $CaseNumber = [string]$Case.CaseNumber
        }
    }
    catch {
        $Problems.Add("Cannot read -CaseFile [ $CaseFile ] => $( $_.Exception.Message )")
    }
}

if (-not $Gui) {
    if (-not $Operator) {
        $Problems.Add('-Operator is required.')
    }
    if (-not $CaseNumber) {
        $Problems.Add('-CaseNumber is required.')
    }
}

$Flags    = [ordered]@{
    RunEdd           = $RunEdd
    CaptureProcesses = $CaptureProcesses
    CaptureRam       = $CaptureRam
    CreateArchive    = $CreateArchive
}

$Resolved = @{}

foreach ($Name in $Flags.Keys) {
    $B = ConvertTo-YesNo -Value $Flags[$Name]
    if ($null -eq $B) {
        $Problems.Add("-$Name must be Y or N (got '$( $Flags[$Name] )').")
    }
    else {
        $Resolved[$Name] = $B
    }
}

# Modules: "all", full names, or 3-digit prefixes. The config order decides the run order.
$Tokens = @(($Modules -join ",") -split "[,;\s]+" | Where-Object { $_ })
if ($Tokens.Count -eq 0 -or $Tokens -contains "all") {
    $Selected = $AllModules
}
else {
    $Chosen = foreach ($T in $Tokens) {
        $Hit = @($AllModules | Where-Object { $_ -eq $T -or $_ -like ($T + "_*") })
        if ($Hit.Count -eq 0) { $Problems.Add("Unknown module [ $T ]. Valid: all, $( $AllModules -join ', ' )") }
        else { $Hit }
    }
    $Selected = @($AllModules | Where-Object { $_ -in $Chosen })
}

if ($OutputRoot -and -not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
    $Problems.Add("-OutputRoot does not exist [ $OutputRoot ]")
}

if ($Problems.Count -gt 0) {
    foreach ($P in $Problems) {
        Show-Message -Message $P -Level ERROR
    }
    Show-Usage
    exit 2
}

# Show exactly what will happen (the command line is also recorded in case_info.json)
if (-not $Gui) {
    Show-TriageBanner
    $Yn = { param($b) if ($b) { "YES" } else { "NO" } }
    Show-Message -Message "---------------------------------------------------------" -NoTime -MessageColor Cyan
    Show-Message -Message "Operator          : $Operator"                             -NoTime -MessageColor Cyan
    Show-Message -Message "Agency            : $Agency"                               -NoTime -MessageColor Cyan
    Show-Message -Message "Case Number       : $CaseNumber"                           -NoTime -MessageColor Cyan
    Show-Message -Message "Modules           : $( $Selected -join ', ' )"             -NoTime -MessageColor Cyan
    Show-Message -Message "EDD               : $( & $Yn $Resolved.RunEdd )"           -NoTime -MessageColor Cyan
    Show-Message -Message "Process Capture   : $( & $Yn $Resolved.CaptureProcesses )" -NoTime -MessageColor Cyan
    Show-Message -Message "RAM Capture       : $( & $Yn $Resolved.CaptureRam )"       -NoTime -MessageColor Cyan
    Show-Message -Message "Create Archive    : $( & $Yn $Resolved.CreateArchive )"    -NoTime -MessageColor Cyan
    Show-Message -Message "---------------------------------------------------------" -NoTime -MessageColor Cyan
}
if ($DryRun) {
    Show-Message -Message "Dry run => nothing was collected." -Level INFO -MessageColor DarkGreen
    exit 0
}

$Options = @{
    Operator         = $Operator
    Agency           = $Agency
    CaseNumber       = $CaseNumber
    Modules          = $Selected
    RunEdd           = $Resolved.$RunEdd
    CaptureProcesses = $Resolved.$CaptureProcesses
    CaptureRam       = $Resolved.$CaptureRam
    CreateArchive    = $Resolved.$CreateArchive
}

try {
    if ($Gui) {
        $Result = Get-Gui -OutputRoot $OutputRoot
        if (-not $Result) {
            exit 0
        }
    }
    else {
        Get-InitialSetup -OutputRoot $OutputRoot
        Write-LaunchContext
        Disable-PSReadLineHistory
        Show-Message -Message "Results folder => [ $global:ResultsFolder ]" -Level INFO -AddToLog
        $null = Invoke-DfirTriageScan -ResultsFolder $global:ResultsFolder @Options
        $Result = $global:TriageResult
    }
}
catch {
    Show-Message -Message "FATAL ERROR => $( $_.Exception.Message )" -Level ERROR -AddToLog
    exit 3
}

if (-not $Result) { exit 3 }
exit $Result.ExitCode


#TODO -- Tooling. Add PSScriptAnalyzer and a few Pester tests with mocked collectors. Either would have caught most of the table above.