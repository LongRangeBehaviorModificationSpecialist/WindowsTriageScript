<#
.SYNOPSIS
    Launcher for the VECTOR Windows triage suite.
.DESCRIPTION
    Interactive by default: asks every question up front, then collects with no
    further prompts.
    With `-Unattended` (or when no console is available) nothing is ever
    prompted; supply `-Operator` and `-CaseNumber` plus any collection switches wanted.
.PARAMETER Modules
    Any of:
        001_Device,
        002_Users,
        003_Network,
        004_Process,
        005_System,
        006_Prefetch,
        007_Event_Logs,
        008_Firewall,
        009_Encryption,
        010_Internet.
    Default: all.
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

    Last Updated: 06-Oct-2026
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

    $ComputerName = $env:COMPUTERNAME

    # Load the toolkit
    try {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath "modules\triage.psd1") -Force -ErrorAction Stop
        $null = Get-TriageConfig
        $AllModules = (Get-TriageConfig -Key "Modules")
    }
    catch {
        Write-Host "CRITICAL: cannot load the triage module => $( $_.Exception.Message )" -ForegroundColor Red
        exit 2
    }

    # Validate parameters
    # Under `-File`, a comma list can arrive as ONE string, so split
    # it ourselves.
    $Modules = if ($Modules) {
        @($Modules -split "[,;\s]+" | Where-Object { $_ })
    }
    else {
        $AllModules
    }

    $Bad = @($Modules | Where-Object { $_ -notin $AllModules })

    if ($Bad) {
        Show-Message -Message "Unknown module(s) => $($Bad -join ', ').  Valid => $($AllModules -join ', ')" -Level ERROR
        exit 2
    }

    if ($OutputRoot -and -not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
        Show-Message -Message "OutputRoot does not exist => $OutputRoot" -Level ERROR
        exit 2
    }

    # Set Mode
    $Interactive = (-not $Unattended) -and (Test-TriageInteractive)

    # Gather everything up front
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
            $RunEdd = Read-YesNo "Run Encrypted Disk Detector on $( $ComputerName )?"
        }
        if (-not $PSBoundParameters.ContainsKey("CaptureProcesses")) {
            $CaptureProcesses = Read-YesNo "Run MAGNET Process Capture on $( $ComputerName )?"
        }
        if (-not $PSBoundParameters.ContainsKey("CaptureRam")) {
            $CaptureRam = Read-YesNo "Run MAGNET RAM Capture on $( $ComputerName )?"
        }
        if (-not $PSBoundParameters.ContainsKey("CreateArchive")) {
            $CreateArchive = Read-YesNo "Package the results into a .zip when finished?"
        }
        [void](Read-LogHost -Prompt "Press [ENTER] to begin collection" -PromptColor Green)
    }
    else {
        $Missing = @()
        if (-not $Operator)   { $Missing += "-Operator" }
        if (-not $CaseNumber) { $Missing += "-CaseNumber" }
        if ($Missing) {
            Show-Message -Message "Unattended run requires => $( $Missing -join ', ' )" -Level ERROR
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
            $Result = Get-Gui -OutputRoot $OutputRoot
            if (-not $Result) { exit 0 }
        }
        else {

            Get-InitialSetup -OutputRoot $OutputRoot
            Write-LaunchContext
            Disable-PSReadLineHistory

            Show-Message -Message "Results folder => [ $global:ResultsFolder ]" -Level INFO -AddToLog -MessageColor Green
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
}


# Structure

#TODO -- Event logs. Export native .evtx with wevtutil epl instead of Get-WinEvent | Select * | Sort | CSV, which loads the whole Security log into RAM and loses fidelity. Add WMI-Activity, BITS-Client, WinRM, CodeIntegrity and Firewall logs.

#TODO -- Persistence.  Add WMI event subscriptions (root\subscription), IFEO, all services (not just running ones), startup folders and BITS jobs. Get-IeExtensions and Temporary Internet Files are rarely useful now.

#TODO -- `Get-WindowsUpdateLog` writes to the Desktop and pulls symbols over the network. Copy the raw ETLs instead.

#TODO -- `dism /online` starts TrustedInstaller and writes logs.

#  Collection gaps and quality

#TODO -- Raw artifacts. You have listings and text dumps but few originals. Add raw copies of SYSTEM/SOFTWARE/SAM/SECURITY/Amcache.hve, each user's NTUSER.DAT and UsrClass.dat, the .pf files (you only export their metadata), SRUM, $MFT/$UsnJrnl, LNK and jump lists, and browser DBs with WAL files.


#TODO -- Volatile extras. ARP, routes, qwinsta, Get-SmbSession/Get-SmbOpenFile, Defender detections and quarantine. Firefox is missing, and the browser SQL hardcodes "GMT+3 IL" columns and has a %H:%M:S typo. Stay in UTC.

# Manifest and README.

#TODO -- Tooling. Add PSScriptAnalyzer and a few Pester tests with mocked collectors. Either would have caught most of the table above.