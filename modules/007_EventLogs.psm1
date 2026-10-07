function Get-TriageEventLogData {
    [CmdletBinding()]
    param (
        [string]$EventLogFolder
    )

    function Get-AvailableLogFiles {
        param(
            [string]$OutputFile = "$EventLogFolder\available_log_files.txt"
        )
        $Command = { Get-WinEvent -ListLog * |
                        Where-Object { $_.IsEnabled } |
                        Select-Object LogName, RecordCount, FileSize, LogMode, LogFilePath, LastWriteTime |
                        Sort-Object -Property @{ Expression = "RecordCount"; Descending = $true } }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-EventLogEntryCount {
        <#
        .SYNOPSIS
            Gets the count of entries in each event log.
            `$null` = log does not exist; `-1` = exists but no count; otherwise the record count
            Reads log metadata only. No events are loaded.
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
            [Parameter(Mandatory)][string]$LogName,
            [Parameter(Mandatory)][string]$OutputFile
        )
        # Throws if missing or failed its hash check
        $Wevtutil = Get-TriageBinary "wevtutil"

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
            Show-Message -Message "Event log export needs about $NeedMb MB but $FreeMb MB is free on $( $Drive.Name )." -Level WARNING -AddToLog
        }
        else {
            Show-Message -Message "Event log export needs about $NeedMb MB; $FreeMb MB is free." -Level INFO -AddToLog
        }
    }
    # UNC destinations cannot be checked this way; wevtutil reports a full disk itself
    catch { }

    Invoke-TriageTask -Message "Gathering list of available Event Log files..." `
        -Action { Get-AvailableLogFiles } `
        -ExpectedFile (Join-Path -Path $EventLogFolder -ChildPath "available_log_files.txt")

    foreach ($LogName in (Get-TriageConfig -Key "EventLogs")) {
        $Count = Get-EventLogEntryCount -LogName $LogName
        if ($null -eq $Count) {
            Show-Message -Message "Event Log [ $( $LogName ) ] was not found on this computer." -Level INFO -AddToLog -MessageColor Yellow
            continue
        }

        $Label = if ($Count -lt 0) {
            "entry count unavailable"
        }
            elseif ($Count -eq 1) {
                "1 entry"
            }
            else {
                [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0:N0} entries", $Count)
            }

        $Out = Join-Path -Path $EventLogFolder -ChildPath (($LogName -replace "[\\/]", "%4") + ".evtx")

        Invoke-TriageTask -Message "Exporting [ $( $LogName ) ] log ($Label)..." `
            -Action { Export-NativeEventLog -LogName $LogName -OutputFile $Out } `
            -ExpectedFile $Out
    }
}
