function Invoke-DfirTriageScan {
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

    $global:TriageTimings = [System.Collections.Generic.List[object]]::new()
    $StartTime = Get-Date
    $global:TriageErrorCount   = 0
    $global:TriageWarningCount = 0
    $global:TriageResult       = $null
    Show-Message -Message "Script Log for VECTOR DFIR Script Usage" -Level INFO -AddToLog
    Show-Message -Message "[ $( $MyInvocation.MyCommand.Name ) ] execution started." -Level INFO -AddToLog

    Write-CaseInfo -ResultsFolder $ResultsFolder -Operator $Operator -Agency $Agency `
        -CaseNumber $CaseNumber -Selected ([ordered]@{
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
                Show-Message -Message "Module $FolderName finished `
                    ($( Format-TriageDuration -Span $ModuleSw.Elapsed ))" `
                    -Level INFO -AddToLog -MessageColor Magenta
            }
            catch {
                $ErrorMsg = "Execution failed during $FolderName on $( $env:COMPUTERNAME ). Error => $( $_.Exception.Message )"
                Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
            }
        }

        $DfirScanWorkflow = [ordered]@{
            "001" = { param($FolderName) Get-TriageDeviceData -DeviceFolder $FolderName }
            "002" = { param($FolderName) Get-TriageUserData -UserFolder $FolderName }
            "003" = { param($FolderName) Get-TriageNetworkData -NetworkFolder $FolderName }
            "004" = { param($FolderName) Get-TriageProcessData -ProcessFolder $FolderName }
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
                Show-Message -Message "Config lists [ $Listed ] but triage.psm1 has no action for it." `
                    -Level WARNING -AddToLog
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

    Show-Message -Message "Collection finished => $( $global:TriageErrorCount ) error(s), $( $global:TriageWarningCount ) warning(s) so far. Hashing evidence..." `
        -Level INFO -AddToLog -MessageColor Magenta

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
    Show-Message -Message "    File Name: final_hashes.csv (SHA-256 => $( $Closed.FinalHashesSha256 ))" `
        -Level INFO -MessageColor Yellow

    if ($Archive) {
        Show-Message -Message "    File Name: $( Split-Path -Path $ArchiveResult.ZipPath -Leaf ) `
            (SHA-256 => $( $ArchiveResult.Sha256 ))" -Level INFO -MessageColor Yellow
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

    Show-Message -Message ("Data collection completed in {0:hh\:mm\:ss}" -f $Duration) -Level INFO
    Show-Message -Message "$global:TriageErrorCount error(s), $global:TriageWarningCount warning(s)" -Level INFO
    Show-Message -Message "Exit code: $Code" -Level INFO
    Show-Message -Message "Results saved to [ $ResultsFolder ]" -Level INFO
}

# Force the .NET Garbage Collector to immediately purge the freed memory slots
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
