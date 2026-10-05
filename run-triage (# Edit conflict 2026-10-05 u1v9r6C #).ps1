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

    Last Updated: 05-Oct-2026
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

    $AllModules = @(
        "001_Device",
        "002_Users",
        "003_Network",
        "004_Process",
        "005_System",
        "006_Prefetch",
        "007_Event_Logs",
        "008_Firewall",
        "009_Encryption",
        "010_Internet"
    )

    $global:ToolkitRoot = $PSScriptRoot

    $ComputerName = $env:COMPUTERNAME

    # Load the toolkit
    try {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath "modules\triage.psd1") -Force -ErrorAction Stop
    }
    catch {
        Write-Host "CRITICAL: cannot load the triage module => $( $_.Exception.Message )" -ForegroundColor Red; exit 2
    }

    # Check for Administrator Rights -- Volatile collection (Network, RAM,
    # Handles) will fail silently without this.
    $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $IsAdmin) {
        Show-Message "CRITICAL ACCESS ERROR => This triage tool must be run as Administrator." -Level ERROR
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
        Show-Message -Message "Unknown module(s): $($Bad -join ', '). Valid: $($AllModules -join ', ')" -Level ERROR
        exit 2
    }

    if ($OutputRoot -and -not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
        Show-Message -Message "OutputRoot does not exist: $OutputRoot" -Level ERROR
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
        [void](Read-LogHost -Prompt "Press [ENTER] to begin collection" -PromptColor Yellow)
    }
    else {
        $Missing = @()
        if (-not $Operator)   { $Missing += "-Operator" }
        if (-not $CaseNumber) { $Missing += "-CaseNumber" }
        if ($Missing) {
            Show-Message -Message "Unattended run requires: $( $Missing -join ', ' )" -Level ERROR
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
            # Show-TriageBanner
            Write-LaunchContext
            Disable-PSReadLineHistory

            Show-Message -Message "Results folder => $global:ResultsFolder" -Level INFO -AddToLog -MessageColor Green
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


#TODO -- `Get-WindowsUpdateLog` writes to the Desktop and pulls symbols over the network. Copy the raw ETLs instead.

#TODO -- `dism /online` starts TrustedInstaller and writes logs.

#  Collection gaps and quality

#TODO -- Raw artifacts. You have listings and text dumps but few originals. Add raw copies of SYSTEM/SOFTWARE/SAM/SECURITY/Amcache.hve, each user's NTUSER.DAT and UsrClass.dat, the .pf files (you only export their metadata), SRUM, $MFT/$UsnJrnl, LNK and jump lists, and browser DBs with WAL files.

#TODO -- Event logs. Export native .evtx with wevtutil epl instead of Get-WinEvent | Select * | Sort | CSV, which loads the whole Security log into RAM and loses fidelity. Add WMI-Activity, BITS-Client, WinRM, CodeIntegrity and Firewall logs.

#TODO -- Persistence. Add WMI event subscriptions (root\subscription), IFEO, all services (not just running ones), startup folders and BITS jobs. Get-IeExtensions and Temporary Internet Files are rarely useful now.

#TODO -- Volatile extras. ARP, routes, qwinsta, Get-SmbSession/Get-SmbOpenFile, Defender detections and quarantine. Firefox is missing, and the browser SQL hardcodes "GMT+3 IL" columns and has a %H:%M:S typo. Stay in UTC.

#\TODO -- Speed. Get-EstablishedConnections calls Get-Process five times per connection and .Modules throws on protected processes. Build a PID lookup once, or use Win32_Process. Cache hashes by path in 004, and use $env:SystemDrive/$env:SystemRoot rather than a hardcoded C:\Windows.

# Structure

#TODO -- One runner. Invoke-ScriptBlock is pasted into 10 modules, and each of ~60 collectors repeats $Command = {...}; $Data = &($Command); Write-Output.... A single data-driven runner also fixes the false "SUCCESS" message, which currently prints even when a non-terminating error left an empty file.

<#
function Invoke-Collector {
    param(
        [string]$Name,
        [scriptblock]$Script,
        [string]$OutFile,
        [ValidateSet("Csv","Json","Text")][string]$Format = "Csv"
    )

    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $data = & $Script
        switch ($Format) {
            "Csv" { $data | Export-Csv $OutFile -NoTypeInformation -Encoding UTF8 }
            "Json" { $data | ConvertTo-Json -Depth 5 | Set-Content $OutFile -Encoding UTF8 }
            "Text" { $data | Out-String -Width 4096 | Set-Content $OutFile -Encoding UTF8 }
        }
        if (-not (Test-Path $OutFile) -or (Get-Item $OutFile).Length -eq 0) { throw "No output produced" }

        Write-TriageLog SUCCESS "$Name => $(Split-Path $OutFile -Leaf) ($([int]$sw.Elapsed.TotalSeconds)s)"
    }
    catch { Write-TriageLog ERROR "$Name failed: $( $_.Exception.Message )" }
}

$Collectors = @(
    @{ Name = "Startup commands"; Out = "startup.csv"; Format = "Csv"
       Script = { Get-CimInstance Win32_StartupCommand } }
)
foreach ($c in $Collectors) {
    Invoke-Collector -Name $c.Name -Script $c.Script -OutFile (Join-Path -Path $Folder -ChildPath $c.Out) -Format $c.Format
}
#>

#TODO -- Text dumps. Out-File truncates narrow tables with ..., so prefer CSV/JSON or Out-String -Width. Also standardize encoding, since you currently mix UTF-8 and default.

#TODO -- Single root module. Nested modules can't reliably see each other's functions, so you depend on $global:LogFile, $global:ResultsFolder and $global:Binaries. One root .psm1 dot-sourcing Public/ and Private/ removes that, and $Dlu, $ExecutableFileTypes and $Binaries (defined in two places) collapse to one config.

# Manifest and README.

#TODO -- The manifest says CompatiblePSEditions = Core while other code is 5.1-only (.ipv4address, Get-WindowsUpdateLog) or 7-only (EnumerationOptions). Pick 5.1 unless you'll test both.

#TODO -- Tooling. Add PSScriptAnalyzer and a few Pester tests with mocked collectors. Either would have caught most of the table above.