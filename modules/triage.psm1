function Invoke-DfirTriageScan {
    <#
    .SYNOPSIS
        Runs a complete triage collection: case record, optional captures,
        the selected modules, evidence hashing, and an optional case archive.

    .DESCRIPTION
        This is the main entry point of the toolkit.  Both `run-triage.ps1`
        and the GUI call it. In order, it:

            1.  Resets the error and warning counters, the task timing list,
                and `$global:TriageResult`, and writes the opening lines to
                the log.
            2.  Writes the case record (`case_info.json`) with
                `Write-CaseInfo`.
            3.  Verifies the tools in the `\bin\ folder with
                `Initialize-TriageSystemTools`.
            4.  Runs the optional captures that were selected, in this order:
                (a) Magnet RAM Capture [-CaptureRam | -Ram],
                (b) Encrypted Disk Detector [-RunEdd | -Edd], and
                (c) Magnet Process Capture [-GetProcesses | -GP].
            5.  Mounts the user registry hives, runs each selected module
                into its own subfolder of the results folder, and dismounts
                the hives.  The dismount happens even if a module fails.
            6.  Saves the task timings to `\Logs\task_timings.csv`, hashes all
                evidence with `Get-FileHashes`, and closes and hashes the
                log with `Close-TriageLog`.
            7.  Creates a ZIP of the results folder if -Archive was given
                (`Invoke-CaseArchive`).
            8.  Shows the values to record in the case notes (the hash of
                `final_hashes.csv` and, if made, of the ZIP), and stores a
                summary in `$global:TriageResult`.

        Modules always run in the fixed order of the internal workflow table,
        not in the order given in -Modules.

        Modules that are not selected are logged as skipped.

        A module that throws is logged as an error and the run continues with
        the next one.

        The exit code in the summary is 1 if any error was recorded and 0
        otherwise.

        Warnings do not change the exit code.

    .PARAMETER ResultsFolder
        Path of the case results folder.
        Normally created beforehand by `Get-InitialSetup`, which also creates
        the log.

    .PARAMETER Operator
        Name of the person running the collection.
        Recorded in `case_info.json`.

    .PARAMETER CaseNumber
        The case number.
        Recorded in `case_info.json`.

    .PARAMETER Agency
        The agency name.
        Optional; recorded in `case_info.json`.

    .PARAMETER Modules
        Names of the modules to run, such as "001_Device" and "003_Network".
        Defaults to every module listed in `TriageConfig.psd1`.
        Each name must match the workflow table exactly.

    .PARAMETER RunEdd
        Runs Encrypted Disk Detector before the modules.

    .PARAMETER GetProcesses
        Captures the memory of running processes with Magnet Process Capture.

    .PARAMETER CaptureRam
        Captures physical memory with Magnet RAM Capture.

    .PARAMETER Archive
        Creates a ZIP of the results folder and a .sha256 file after the
        log is closed.

    .INPUTS
        None.
        This function does not accept pipeline input.

    .OUTPUTS
        None on the pipeline.

        Results are written to the results folder, and a summary object is
        stored in `$global:TriageResult` with these properties:
            ExitCode,
            Errors,
            Warnings,
            ResultsFolder,
            LogFile, and
            Duration.

    .EXAMPLE
        Invoke-DfirTriageScan `
            -ResultsFolder $global:ResultsFolder `
            -Operator "SA John Doe" `
            -CaseNumber "2026-12345"

        Runs every module with no optional captures and no archive.

    .EXAMPLE
        Invoke-DfirTriageScan `
            -ResultsFolder $global:ResultsFolder `
            -Operator "SA John Doe" `
            -CaseNumber "2026-12345" `
            -Modules "001_Device", "003_Network" `
            -CaptureRam `
            -Archive `
            $global:TriageResult.ExitCode

        Runs two modules, captures RAM, creates an archive, and then reads the
        exit code.

    .NOTES
        Run from an elevated PowerShell session with the toolkit's bin folder
        present.
        Uses these global variables:
            `ToolkitRoot` (read),
            `TriageTimings`,
            `TriageErrorCount`,
            `TriageWarningCount`,
            `TriageResult`, and
            `TriageUserHives` (set).

        The nested functions `Initialize-TriageScan` and `Invoke-TriageScan`
        are private to this function.

        Because the memory captures and the case record run before the modules,
        the most volatile data is collected first; only the hash and archive
        steps depend on the log being closed.

    .LINK
        Get-Gui

    .LINK
        Write-CaseInfo

    .LINK
        Get-FileHashes

    .LINK
        Invoke-CaseArchive
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResultsFolder,

        [Parameter(Mandatory)]
        [string]$Operator,

        [Parameter(Mandatory)]
        [string]$CaseNumber,

        [string]$Agency = "",

        [string[]]$Modules = @(Get-TriageConfig -Key "Modules"),

        [switch]$CaptureRam,
        [switch]$RunEdd,
        [switch]$GetProcesses,
        [switch]$Archive
    )

    $global:TriageTimings = [System.Collections.Generic.List[object]]::New()
    $StartTime = Get-Date
    $global:TriageErrorCount   = 0
    $global:TriageWarningCount = 0
    $global:TriageResult       = $null

    Show-Message `
        -Message "Script Log for VECTOR DFIR Script Usage" `
        -Level INFO `
        -AddToLog
    Show-Message `
        -Message "[ $( $MyInvocation.MyCommand.Name ) ] execution started." `
        -Level INFO `
        -AddToLog

    Write-CaseInfo `
        -ResultsFolder $ResultsFolder `
        -Operator $Operator `
        -Agency $Agency `
        -CaseNumber $CaseNumber `
        -Selected ([ordered]@{
            Modules      = $Modules
            RunEdd       = [bool]$RunEdd
            GetProcesses = [bool]$GetProcesses
            CaptureRam   = [bool]$CaptureRam
            Archive      = [bool]$Archive
        })

    Initialize-TriageSystemTools -ToolkitRoot $global:ToolkitRoot

    # Optional captures: the decision was made up front, so just
    # checking for which switches, if any, were passed.
    # Follows the order of volatility - RAM, Edd, then Processes.

    if (-not $CaptureRam) {
        $Msg = "Skipped [ Magnet RAM Capture ] (not selected)."
        Show-Message -Message $Msg -Level INFO -AddToLog
    }
    else {
        Get-ComputerRam -ResultsFolder $ResultsFolder
    }
    if (-not $RunEdd) {
        $Msg = "Skipped [ Encrypted Disk Detector ] (not selected)."
        Show-Message -Message $Msg -Level INFO -AddToLog
    }
    else {
        Invoke-EDD -ResultsFolder $ResultsFolder
    }

    if (-not $GetProcesses) {
        $Msg = "Skipped [ Magnet Process Capture ] (not selected)."
        Show-Message -Message $Msg -Level INFO -AddToLog
    }
    else {
        Get-RunningProcesses -ResultsFolder $ResultsFolder
    }

    if (-not $Archive) {
        $Msg = "Skipped [ Creating Case Archive ] (not selected)."
        Show-Message -Message $Msg -Level INFO -AddToLog
    }

    function Initialize-TriageScan {
        [CmdletBinding()]
        param(
            [string]$ResultsFolder,
            [string[]]$Modules
        )

        function Invoke-TriageScan {
            param(
                [string]$ResultsFolder,
                [string]$FolderName,
                [scriptblock]$Action
            )

            try {
                $SubFolderPathName = Join-Path -Path $ResultsFolder -ChildPath $FolderName
                $null = New-Item -ItemType Directory -Path $SubFolderPathName -Force

                Test-IfExists -FolderName $SubFolderPathName -Type FOLDER
                $ModuleSw = [System.Diagnostics.Stopwatch]::StartNew()
                & $Action $SubFolderPathName
                $Msg = "Module $FolderName finished ($( Format-TriageDuration -Span $ModuleSw.Elapsed ))"
                Show-Message -Message $Msg -Level INFO -AddToLog -MessageColor Magenta
            }
            catch {
                $ErrorMsg = "Execution failed during $FolderName on $( $env:COMPUTERNAME ).  " +
                    "Error => $( $_.Exception.Message )"
                Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
            }
        }

        $DfirScanWorkflow = [ordered]@{
            "001" = { param($FolderName) Get-TriageDeviceData -DeviceFolder $FolderName }
            "002" = { param($FolderName) Get-TriageUserData -UserFolder $FolderName }
            "003" = { param($FolderName) Get-TriageNetworkData -NetworkFolder $FolderName }
            "004" = { param($FolderName) Get-TriageProcessData -ProcessesFolder $FolderName }
            "005" = { param($FolderName) Get-TriageSystemData -SystemFolder $FolderName }
            "006" = { param($FolderName) Get-TriagePrefetchData -PrefetchFolder $FolderName }
            "007" = { param($FolderName) Get-TriageEventLogData -EventLogFolder $FolderName }
            "008" = { param($FolderName) Get-TriageFirewallData -FirewallFolder $FolderName }
            "009" = { param($FolderName) Get-TriageEncryptionData -EncryptionFolder $FolderName }
            "010" = { param($FolderName) Get-TriageInternetData -InternetFolder $FolderName }
            "011" = { param($FolderName) Get-TriageRawArtifactsData -RawFolder $FolderName }
        }

        # Warn if the config lists a module that has no code behind it
        foreach ($Listed in (Get-TriageConfig -Key "Modules")) {
            if (-not $DfirScanWorkflow.Contains(($Listed -split "_")[0])) {
                $NoActionMsg = "Config lists [ $Listed ] but triage.psm1 has no action for it."
                Show-Message -Message $NoActionMsg -Level WARNING -AddToLog
            }
        }

        foreach ($Entry in $DfirScanWorkflow.GetEnumerator()) {
            $Name = Resolve-TriageModuleName -Id $Entry.Key
            if ($Modules -notcontains $Name) {
                Show-Message -Message "Skipped module [ /$Name/ ] (not selected)" `
                    -Level INFO -AddToLog
                continue
            }
            Invoke-TriageScan -ResultsFolder $ResultsFolder -FolderName $Name -Action $Entry.Value
        }
    }

    $Scratch = Join-Path `
        -Path (Get-TriageConfig -Key "ToolkitRoot") `
        -ChildPath (Get-TriageConfig).Defaults.ScratchFolder
    $global:TriageUserHives = @()

    try {
        $global:TriageUserHives = @(Mount-TriageUserHives -HiveFolder (Join-Path -Path $ResultsFolder `
            -ChildPath "Registry_Hives") -ScratchFolder $Scratch)

        foreach ($Hive in $global:TriageUserHives) {
            Show-Message -Message "User hive: $( $Hive.UserName ) [ $( $Hive.Sid ) ] - $( $Hive.Note )" `
                -Level INFO -AddToLog
        }

        Initialize-TriageScan -ResultsFolder $ResultsFolder -Modules $Modules
    }
    finally {
        Dismount-TriageUserHives -Hives $global:TriageUserHives -ScratchFolder $Scratch
    }

    $FinishMsg = "Collection finished => $( $global:TriageErrorCount ) error(s), " +
        "$( $global:TriageWarningCount ) warning(s) so far. Hashing evidence..."
    Show-Message -Message $FinishMsg -Level INFO -AddToLog -MessageColor Magenta

    $global:TriageTimings | Export-Csv -LiteralPath (Join-Path -Path $ResultsFolder -ChildPath `
        "Logs\task_timings.csv") -NoTypeInformation -Encoding UTF8

    Get-FileHashes -ResultsFolder $ResultsFolder

    Show-Message -Message "Closing the log..." -Level INFO -AddToLog
    Show-Message -Message "**END OF LOG FILE**" -Level INFO -AddToLog
    $Closed = Close-TriageLog -ResultsFolder $ResultsFolder

    $Archive = $null
    if ($Archive) {
        $ArchiveResult = Invoke-CaseArchive -ResultsFolder $ResultsFolder
    }
    else {
        continue
    }

    Show-Message -Message "RECORD THESE VALUES IN YOUR CASE NOTES:" -Level INFO
    $FileNameMsg = "    File Name: final_hashes.csv (SHA-256 => $( $Closed.FinalHashesSha256 ))"
    Show-Message -Message $FileNameMsg -Level INFO -MessageColor Yellow

    if ($Archive) {
        $ArchiveMsg = "    File Name: $( Split-Path -Path $ArchiveResult.ZipPath -Leaf ) " +
            "(SHA-256 => $( $ArchiveResult.Sha256 ))"
        Show-Message -Message $ArchiveMsg -Level INFO -MessageColor Yellow
    }

    $Duration = (Get-Date) - $StartTime

    $Code = if ($global:TriageErrorCount -gt 0) { 1 } else { 0 }

    $global:TriageResult = [PSCustomObject]@{
        ExitCode      = $Code
        Errors        = $global:TriageErrorCount
        Warnings      = $global:TriageWarningCount
        ResultsFolder = $ResultsFolder
        LogFile       = $Closed.LogFile
        Duration      = $Duration
    }

    Show-Message `
        -Message ("Data collection completed in {0:hh\:mm\:ss}" -f $Duration) `
        -Level INFO
    $ErrWarnCountMsg = "$global:TriageErrorCount error(s), $global:TriageWarningCount warning(s)"
    Show-Message -Message $ErrWarnCountMsg -Level INFO
    Show-Message -Message "Exit code: $Code" -Level INFO
    Show-Message -Message "Results saved to [ $ResultsFolder ]" -Level INFO
}

# Force the .NET Garbage Collector to immediately purge the freed memory slots
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
