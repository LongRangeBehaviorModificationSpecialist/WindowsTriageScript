function Invoke-DfirTriageScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ResultsFolder,
        [Parameter(Mandatory)][string]$Operator,
        [Parameter(Mandatory)][string]$CaseNumber,
        [string]$Agency = '',
        [string[]]$Modules = @('001_Device','002_Users','003_Network','004_Process','005_System','006_Prefetch','007_Event_Logs','008_Firewall','009_Encryption','010_Internet'),
        [switch]$RunEdd,
        [switch]$CaptureProcesses,
        [switch]$CaptureRam,
        [switch]$CreateArchive
    )

    begin {
        $StartTime = Get-Date
        $global:TriageErrorCount   = 0
        $global:TriageWarningCount = 0
        $global:TriageResult       = $null
        Write-ShowMessage -Message "Script Log for VECTOR DFIR Script Usage" -Level SUCCESS -AddToLog
        Write-ShowMessage -Message "'$( $MyInvocation.MyCommand.Name )' execution started." -Level SUCCESS -AddToLog
    }
    process {
        Show-IsAdmin
        Show-Message -Message "Operator: $Operator | Agency: $Agency | Case: $CaseNumber" -Level INFO -AddToLog -MessageColor Yellow

        Write-CaseInfo -ResultsFolder $ResultsFolder -Operator $Operator -Agency $Agency -CaseNumber $CaseNumber -Selected ([ordered]@{
            Modules = $Modules;
            RunEdd = [bool]$RunEdd;
            CaptureProcesses = [bool]$CaptureProcesses;
            CaptureRam = [bool]$CaptureRam;
            CreateArchive = [bool]$CreateArchive
        })

        Initialize-TriageSystemTools -ToolkitRoot $global:ToolkitRoot

        # Optional captures: the decision was made up front, so just branch
        if ($RunEdd) {
            Invoke-EncryptedDiskDetector -ResultsFolder $ResultsFolder
        }
        else {
            Show-Message -Message "Skipped Encrypted Disk Detector (not selected)." -Level INFO -AddToLog -MessageColor Yellow
        }

        if ($CaptureProcesses) {
            Get-RunningProcesses -ResultsFolder $ResultsFolder
        }
        else {
            Show-Message -Message "Skipped Magnet Process Capture (not selected)." -Level INFO -AddToLog -MessageColor Yellow
        }

        if ($CaptureRam) {
            Get-ComputerRam -ResultsFolder $ResultsFolder
        }
        else {
            Show-Message -Message "Skipped Magnet RAM Capture (not selected)." -Level INFO -AddToLog -MessageColor Yellow
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
                    $null              = New-Item -ItemType Directory -Path $SubFolderPathName -Force

                    Test-IfExists -FolderName $SubFolderPathName -Type FOLDER
                    & $Action $SubFolderPathName
                }
                catch {
                    $ErrorMsg = "Execution failed during '$FolderName' on $( $env:COMPUTERNAME ). Error => $( $_.Exception.Message )"
                    Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
                }
            }

            $DfirScanWorkflow = [ordered]@{
                "001_Device"     = { param($FolderName) Get-TriageDeviceData -DeviceFolder $FolderName }
                "002_Users"      = { param($FolderName) Get-TriageUserData -UserFolder $FolderName }
                "003_Network"    = { param($FolderName) Get-TriageNetworkData -NetworkFolder $FolderName }
                "004_Process"    = { param($FolderName) Get-TriageProcessData -ProcessFolder $FolderName }
                "005_System"     = { param($FolderName) Get-TriageSystemData -SystemFolder $FolderName }
                "006_Prefetch"   = { param($FolderName) Get-TriagePrefetchData -PrefetchFolder $FolderName }
                "007_Event_Logs" = { param($FolderName) Get-TriageEventLogData -EventLogFolder $FolderName }
                "008_Firewall"   = { param($FolderName) Get-TriageFirewallData -FirewallFolder $FolderName }
                "009_Encryption" = { param($FolderName) Get-TriageEncryptionData -EncryptionFolder $FolderName }
                "010_Internet"   = { param($FolderName) Get-TriageInternetData -InternetFolder $FolderName }
            }

            foreach ($Entry in $DfirScanWorkflow.GetEnumerator()) {
                if ($Modules -notcontains $Entry.Key) {
                    Show-Message -Message "Skipped module => $( $Entry.Key ) (not selected)" -Level INFO -AddToLog -MessageColor Yellow
                    continue
                }
                Invoke-TriageScan -ResultsFolder $ResultsFolder -FolderName $Entry.Key -Action $Entry.Value
            }
        }

        $Scratch = Join-Path $global:ToolkitRoot "_scratch"
        $global:TriageUserHives = @(Mount-TriageUserHives -HiveFolder (Join-Path $ResultsFolder "Registry_Hives") -ScratchFolder $Scratch)

        foreach ($H in $global:TriageUserHives) {
            Show-Message -Message "User hive: $($H.UserName) [$($H.Sid)] - $($H.Note)" -Level INFO -AddToLog
        }

        try {
            Initialize-TriageScan -ResultsFolder $ResultsFolder -Modules $Modules
        }
        finally {
            Dismount-TriageUserHives -Hives $global:TriageUserHives -ScratchFolder $Scratch
        }

        Get-FileHashes -ResultsFolder $ResultsFolder

        if ($CreateArchive) {
            Get-CaseArchive -ResultsFolder $ResultsFolder
        }
        else {
            Show-Message -Message "Skipped: case archive (not selected)." -Level INFO -AddToLog -MessageColor Yellow
        }

        # Summary. Deliberately not -AddToLog: the log was hashed above and
        # must not change afterwards.
        $Duration = (Get-Date) - $StartTime

        $Code = if ($global:TriageErrorCount -gt 0) { 1 } else { 0 }

        $global:TriageResult = [pscustomobject]@{
            ExitCode      = $Code
            Errors        = $global:TriageErrorCount
            Warnings      = $global:TriageWarningCount
            ResultsFolder = $ResultsFolder
            LogFile       = $global:LogFile
            Duration      = $Duration
        }

        Show-Message -Message ("Completed in {0:hh\:mm\:ss}: {1} error(s), {2} warning(s). Exit code {3}. Results: {4}" -f
            $Duration, $global:TriageErrorCount, $global:TriageWarningCount, $Code, $ResultsFolder) -Level SUCCESS
    }
    end {
        # Force the .NET Garbage Collector to immediately purge the freed
        # memory slots
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
}

