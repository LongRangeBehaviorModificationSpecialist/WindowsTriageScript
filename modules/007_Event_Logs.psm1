function Get-TriageEventLogData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$EventLogFolder
    )

    # 07.01
    function Get-AvailableLogFiles {
        param(
            [string]$OutputFile = (
                Join-Path -Path $EventLogFolder -ChildPath "07.01_available_log_files.txt"
            )
        )
        $Data = Get-WinEvent -ListLog * |
            Where-Object { $_.IsEnabled } |
            Select-Object LogName, RecordCount, FileSize, LogMode, LogFilePath, LastWriteTime |
            Sort-Object -Property @{ Expression = "RecordCount"; Descending = $true }
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    function Get-EventLogEntryCount {
        <#
        .SYNOPSIS
        Gets the count of entries in each event log.

        '$null' = log does not exist; '-1' = exists but no count; otherwise the
        record count.

        Reads log metadata only.  No events are loaded.
        #>
        param(
            [string]$LogName
        )
        $Info = Get-WinEvent -ListLog $LogName -ErrorAction SilentlyContinue
        if (-not $Info) {
            return $null
        }
        if ($null -eq $Info.RecordCount) {
            return -1
        }
        [long]$Info.RecordCount
    }


    function Export-NativeEventLog {
        param(
            [Parameter(Mandatory)]
            [string]$LogName,

            [Parameter(Mandatory)]
            [string]$OutputFile
        )
        # Throws if missing or failed its hash check
        $Wevtutil = (Get-TriageBinary "wevtutil")

        # The Event Log service writes the file directly. 2>&1 keeps error text off the screen.
        $Raw  = & $Wevtutil epl $LogName $OutputFile /ow:true 2>&1
        $Code = $LASTEXITCODE

        if ($Code -ne 0) {
            # Do not leave a half-written export behind as if it were evidence
            Remove-Item -LiteralPath $OutputFile -Force -ErrorAction SilentlyContinue
            throw "wevtutil exited with code $Code => $( ($Raw | ForEach-Object { "$_" }) -join ' ' )"
        }
    }


    # Preflight: compare the logs' combined size with the free space on the collection drive
    try {
        $Need = 0L
        foreach ($Name in (Get-TriageConfig -Key "EventLogs")) {
            $Info = Get-WinEvent -ListLog $Name -ErrorAction SilentlyContinue
            if ($Info) {
                $Need += [long]$Info.FileSize
            }
        }

        $Drive = New-Object System.IO.DriveInfo ([System.IO.Path]::GetPathRoot($EventLogFolder))
        $NeedMb = [math]::Round($Need / 1MB)
        $FreeMb = [math]::Round($Drive.AvailableFreeSpace / 1MB)

        if ($Drive.AvailableFreeSpace -lt ($Need * 1.1)) {
            $NeedMbMsg = "Event log export needs about $NeedMb MB but $FreeMb " +
                "MB is free on $( $Drive.Name )."
            Show-Message -Message $NeedMbMsg -Level WARNING -AddToLog
        }
        else {
            $NeedSpaceMsg = "Event log export needs about $NeedMb MB; " +
                "$FreeMb MB is free."
            Show-Message -Message $NeedSpaceMsg -Level INFO -AddToLog
        }
    }
    # UNC destinations cannot be checked this way; wevtutil reports a full disk itself
    catch { }

    $GettingListMsg = "Gathering list of available Event Log files..."
    Invoke-TriageTask `
        -Message $GettingListMsg `
        -Action { Get-AvailableLogFiles } `
        -ExpectedFile (Join-Path -Path $EventLogFolder -ChildPath "available_log_files.txt")

    foreach ($LogName in (Get-TriageConfig -Key "EventLogs")) {
        $Count = Get-EventLogEntryCount -LogName $LogName
        if ($null -eq $Count) {
            $LogNotFoundMsg = "Event Log [ $( $LogName ) ] was not found on this computer."
            Show-Message -Message $LogNotFoundMsg -Level INFO -AddToLog -MessageColor Yellow
            continue
        }

        $Label = if ($Count -lt 0) {
                "Entry Count Unavailable"
            }
            elseif ($Count -eq 1) {
                "1 Entry"
            }
            else {
                [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0:N0} Entries", $Count)
            }

        $Out = Join-Path -Path $EventLogFolder -ChildPath (($LogName -replace "[\\/]", "%4") + ".evtx")

        Invoke-TriageTask -Message "Exporting [ $( $LogName ) ] log ($Label)..." `
            -Action { Export-NativeEventLog -LogName $LogName -OutputFile $Out } `
            -ExpectedFile $Out
    }
}
