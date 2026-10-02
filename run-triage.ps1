<#
.SYNOPSIS
    Launcher for the VECTOR Windows triage suite.
.DESCRIPTION
    Interactive by default: asks every question up front, then collects with no
    further prompts.
    With -Unattended (or when no console is available) nothing is ever
    prompted; supply
    -Operator and -CaseNumber plus any collection switches wanted.
.PARAMETER Modules
    Any of 001_Device, 002_Users, 003_Network, 004_Process, 005_System,
    006_Prefetch, 007_Event_Logs, 008_Firewall, 009_Encryption,
    010_Internet. Default: all.
.EXAMPLE
    .\run-triage.ps1
.EXAMPLE
    .\run-triage.ps1 -Unattended -Operator "J. Smith" -Agency "Example PD" -CaseNumber 2026-0142 -CaptureRam -CreateArchive
.NOTES
    Exit codes: 0 = completed,
                1 = completed with logged errors,
                2 = could not start (not admin, bad parameters, module load
                failed),
                3 = unexpected fatal error.
    Last Updated: 02-Oct-2026
#>
[CmdletBinding()]
param(
    [switch]$Gui,
    [switch]$Unattended,
    [string]$Operator,
    [string]$Agency,
    [string]$CaseNumber,
    [string[]]$Modules,
    [switch]$RunEdd,
    [switch]$CaptureProcesses,
    [switch]$CaptureRam,
    [switch]$CreateArchive,
    [string]$OutputRoot
)

begin {

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Continue

    $AllModules = @("001_Device","002_Users","003_Network","004_Process","005_System","006_Prefetch","007_Event_Logs","008_Firewall","009_Encryption","010_Internet")

    $global:ToolkitRoot = $PSScriptRoot

    $ComputerName = $env:COMPUTERNAME

    # 1. Load the toolkit
    try {
        Import-Module -Name (Join-Path $PSScriptRoot "modules\triage.psd1") -Force -ErrorAction Stop
    }
    catch {
        Write-Host "CRITICAL: cannot load the triage module => $($_.Exception.Message)" -ForegroundColor Red; exit 2
    }

    # Dynamically find the USB drive root directory (avoids hardcoding drive
    # letters)

    # $FunctionsModule = [System.IO.Path]::GetFullPath($(Join-Path -Path $global:ToolkitRoot -ChildPath "modules\functions.psm1"))
    # Import-Module -Name $FunctionsModule -Force
    # Show-Message "The functions.psm1 file was imported successfully"

    # # FORCE the path to convert to an absolute path string (Resolves any .\ or
    # # broken slashes)
    # $ManifestPath = [System.IO.Path]::GetFullPath($(Join-Path -Path $global:ToolkitRoot -ChildPath "modules\triage.psd1"))

    # # Import the Master Manifest Module
    # if (Test-Path -Path $ManifestPath) {
    #     Show-Message "Loading forensic modules..." -MessageColor Green -AddToLog
    #     Import-Module -Name $ManifestPath -Force
    #     Show-Message "Module file: '$( Split-Path $ManifestPath -Leaf )' was imported successfully" -MessageColor Green -AddToLog
    #     Show-Message "Triage Suite loaded successfully..." -MessageColor Green -AddToLog
    # }
    # else {
    #     Show-Message "CRITICAL FILE ERROR: Cannot find the triage manifest at '$ManifestPath'." -Level ERROR -AddToLog
    #     Exit
    # }

    # Check for Administrator Rights
    # Volatile collection (Network, RAM, Handles) will fail silently
    # without this.
    $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $IsAdmin) {
        Show-Message "CRITICAL ACCESS ERROR => This triage tool must be run as Administrator." -Level ERROR
        exit 2
    }

    # 3. Validate parameters.
    # Under -File, a comma list can arrive as ONE string, so split it ourselves.
    $Modules = if ($Modules) {
        @($Modules -split "[,;\s]+" | Where-Object { $_ })
    } else { $AllModules }

    $Bad = @($Modules | Where-Object { $_ -notin $AllModules })

    if ($Bad) {
        Show-Message -Message "Unknown module(s): $($Bad -join ', '). Valid: $($AllModules -join ', ')" -Level ERROR
        exit 2
    }

    if ($OutputRoot -and -not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
        Show-Message -Message "OutputRoot does not exist: $OutputRoot" -Level ERROR
        exit 2
    }

    # 4. Mode
    $Interactive = (-not $Unattended) -and (Test-TriageInteractive)

    # 5. Gather everything up front
    if ($Gui) {
        # the GUI collects its own answers
    }

    elseif ($Interactive) {
        Show-TriageBanner
        if (-not $PSBoundParameters.ContainsKey("Operator")) {
            $Operator = Read-Required "Enter your name for the report: "
        }
        if (-not $PSBoundParameters.ContainsKey("Agency")) {
            $Agency = Read-LogHost -Prompt "Enter Agency Name: "
        }
        if (-not $PSBoundParameters.ContainsKey("CaseNumber")) {
            $CaseNumber = Read-Required "Enter Case Number: "
        }
        if (-not $PSBoundParameters.ContainsKey("RunEdd")) {
            $RunEdd = Read-YesNo "Run Encrypted Disk Detector on $ComputerName?"
        }
        if (-not $PSBoundParameters.ContainsKey("CaptureProcesses")) {
            $CaptureProcesses = Read-YesNo "Run MAGNET Process Capture on $ComputerName?"
        }
        if (-not $PSBoundParameters.ContainsKey("CaptureRam")) {
            $CaptureRam = Read-YesNo "Run MAGNET RAM Capture on $ComputerName?"
        }
        if (-not $PSBoundParameters.ContainsKey("CreateArchive")) {
            $CreateArchive = Read-YesNo "Package the results into a .zip when finished?"
        }
        [void](Read-LogHost -Prompt "Press [ENTER] to begin collection" -PromptColor Yellow)
    }
    else {
        $Missing = @()
        if (-not $Operator)   { $Missing += "-Operator" }
        if (-not $CaseNumber) { $Missing += "-CaseNumber" }
        if ($Missing) {
            Show-Message -Message "Unattended run requires: $($Missing -join ', ')" -Level ERROR
            exit 2
        }
    }

    $Options = @{
        Operator         = $Operator
        Agency           = $Agency
        CaseNumber       = $CaseNumber
        Modules          = $Modules
        RunEdd           = [bool]$RunEdd
        CaptureProcesses = [bool]$CaptureProcesses
        CaptureRam       = [bool]$CaptureRam
        CreateArchive    = [bool]$CreateArchive
    }
}

process {
    try {
        if ($Gui) {
            Disable-PSReadLineHistory
            Write-LaunchContext
            $Result = Get-Gui -OutputRoot $OutputRoot
            if (-not $Result) { exit 0 }
        }
        else {
            function Show-LoadedModules {
                Show-Message "Functions Loaded =>" -MessageColor Green -AddToLog
                foreach ($Cmd in $(Get-Command -Module triage | Select-Object Name)) {
                    Write-Host "$( $Cmd.Name )"
                }
            }

            Get-InitialSetup -OutputRoot $OutputRoot
            Show-TriageBanner
            Write-LaunchContext
            Disable-PSReadLineHistory
            Show-LoadedModules

            Show-Message -Message "Results folder => $global:ResultsFolder" -Level INFO -AddToLog
            $null   = Invoke-DfirTriageScan -ResultsFolder $global:ResultsFolder @Options
            $Result = $global:TriageResult
        }
    }
    catch {
        Show-Message -Message "FATAL ERROR => $($_.Exception.Message)" -Level ERROR -AddToLog
        exit 3
    }
    if (-not $Result) { exit 3 }
    exit $Result.ExitCode
}


#TODO -- Tooling. Add PSScriptAnalyzer and a few Pester tests with mocked collectors. Either would have caught most of the table above.
