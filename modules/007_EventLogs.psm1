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
        # Show-Message -File $OutputFile -Level SUCCESS -AddToLog
    }

    function Get-EventLogEntryCount {
        # $null = log does not exist;
        # -1 = exists but no count;
        # otherwise the record count
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

    function Export-EventLogCsv {
        param(
            [string]$LogName,
            [string]$OutputFile,
            [long]$Count
        )

        if ($Count -eq 0) {
            # Records "no data found" as evidence
            Write-OutputToCsv -Data $null -OutputFile $OutputFile
            return
        }
        try {
            $Data = Get-WinEvent -LogName $LogName -ErrorAction Stop |
                        Select-Object -Property * | Sort-Object -Property TimeCreated -Descending
            Write-OutputToCsv -Data $Data -OutputFile $OutputFile
        }
        catch {
            if ($_.FullyQualifiedErrorId -like "NoMatchingEventsFound*") {
                Write-OutputToCsv -Data $null -OutputFile $OutputFile
            }
            else {
                throw
            }  # the runner logs it as an ERROR
        }
    }


    Invoke-TriageTask -Message "Gathering list of available Event Log files..." `
        -Action { Get-AvailableLogFiles } `
        -ExpectedFile (Join-Path -Path $EventLogFolder -ChildPath "available_log_files.txt")


    foreach ($Log in (Get-TriageConfig -Key "EventLogs")) {
        $Count = Get-EventLogEntryCount -LogName $Log.Log
        if ($null -eq $Count) {
            Show-Message -Message "Event Log [ $( $Log.Log ) ] was not found on this computer." -Level INFO -AddToLog -MessageColor Yellow
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

        $Out = Join-Path $EventLogFolder $Log.File
        Invoke-TriageTask -Message "Getting [ $( $Log.Log ) ] log ($Label)..." `
            -Action { Export-EventLogCsv -LogName $Log.Log -OutputFile $Out -Count $Count } `
            -ExpectedFile $Out
    }
}
