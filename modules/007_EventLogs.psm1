function Get-TriageEventLogData {
    [CmdletBinding()]
    param([string]$EventLogFolder)

    function Invoke-ScriptBlock {
        param(
            [string]$LogName,
            [string]$Message,
            [string]$OutputFile
        )
        try {
            Show-Message -Message $Message -Level INFO -AddToLog

            $EventLogPath = "C:\Windows\System32\winevt\Logs"
            $LogFile = Join-Path -Path $EventLogPath -ChildPath (($LogName -replace "/", "%4") + ".evtx")

            if (-not (Test-Path -LiteralPath $LogFile)) {
                Show-Message -Message "Event Log $( $LogName ) was not found in '$EventLogPath'" -Level INFO -AddToLog -MessageColor Yellow
                return
            }

            $Data = Get-WinEvent -FilterHashtable @{ Logname = $LogName } -ErrorAction Stop |
                    Select-Object -Property * |
                    Sort-Object -Property TimeCreated -Descending

            Write-OutputToCsv -Data $Data -OutputFile $OutputFile
            Show-Message -File $OutputFile -Level SUCCESS -AddToLog
        }
        catch {
            if ($_.FullyQualifiedErrorId -like "NoMatchingEventsFound*") {
                Show-Message -Message "No data was found in the $( $LogName ) Event Log." -Level INFO -AddToLog -MessageColor Yellow
            }
            else {
                Show-Message -Message "Execution failed on $LogName. Error => $( $_.Exception.Message )" -Level ERROR -AddToLog
            }
        }
    }

    function Get-AvailableLogFiles {
        param([string]$OutputFile = "$EventLogFolder\available_log_files.txt")
        $BeginMsg = "Gathering list of available Event Log files..."
        Show-Message -Message $BeginMsg -Level INFO -AddToLog
        $Command = { Get-WinEvent -ListLog * |
                        Where-Object { $_.IsEnabled } |
                        Select-Object LogName, RecordCount, FileSize, LogMode, LogFilePath, LastWriteTime |
                        Sort-Object -Property @{ Expression = "RecordCount"; Descending = $true } }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
        Show-Message -File $OutputFile -Level SUCCESS -AddToLog
    }

    function Get-AllEventLogs {
        param()
        $EventLogList = [ordered]@{
            "Application" = (
                "Getting 'Application' Log...",
                "application_log.csv"
            )
            "Microsoft-Windows-Application-Experience/Program-Inventory" = (
                "Getting 'Microsoft-Windows-Application-Experience%4Program Inventory' Log...",
                "win_application_experience_program_inventory_log.csv"
            )
            "Microsoft-Windows-DriverFrameworks-UserMode/Operational" = (
                "Getting 'Microsoft-Windows-DriverFrameworks-UserMode%4Operational' Log...",
                "win_driveframeworks_usermode_operational_log.csv"
            )
            "Microsoft-Windows-Partition/Diagnostic" = (
                "Getting 'Microsoft-Windows-Partition%4Diagnostic' Log...",
                "win_partition_diagnostic_log.csv"
            )
            "Microsoft-Windows-PowerShell/Admin" = (
                "Getting 'Microsoft-Windows-PowerShell%4Admin' Log...",
                "win_powershell_admin_log.csv"
            )
            "Microsoft-Windows-PowerShell/Operational" = (
                "Getting 'Microsoft-Windows-PowerShell%4Operational' Log...",
                "win_powershell_operational_log.csv"
            )
            "Microsoft-Windows-Sysmon/Operational" = (
                "Getting 'Microsoft-Windows-Sysmon%4Operational' Log...",
                "win_sysmon_operational_log.csv"
            )
            "Microsoft-Windows-TaskScheduler/Operational" = (
                "Getting 'Microsoft-Windows-TaskScheduler%4Operational' Log...",
                "win_taskscheduler_operational_log.csv"
            )
            "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" = (
                "Getting 'Microsoft-Windows-TerminalServices-LocalSessionManager%4Operational' Log...",
                "windows_terminalservices_localsessionmanager_operational_log.csv"
            )
            "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational" = (
                "Getting 'Microsoft-Windows-TerminalServices-RemoteConnectionManager%4Operational' Log...",
                "win_terminalservices_remoteconnectionmanager_operational_log.csv"
            )
            "Microsoft-Windows-TerminalServices-RDPClient/Operational" = (
                "Getting 'Microsoft-Windows-TerminalServices-RDPClient%4Operational' Log...",
                "win_terminalservices_rdpclient_operational_log.csv"
            )
            "Microsoft-Windows-Windows Defender/Operational" = (
                "Getting 'Microsoft-Windows-Windows Defender%4Operational' Log...",
                "win_windows_defender_operational_log.csv"
            )
            "Microsoft-Windows-Windows Defender/WHC" = (
                "Getting 'Microsoft-Windows-Windows Defender%4WHC' Log...",
                "win_windows_defender_whc_log.csv"
            )
            "Security" = (
                "Getting 'Security' Log...",
                "security_log.csv"
            )
            "System" = (
                "Getting 'System' Log...",
                "system_log.csv"
            )
            "Windows-PowerShell" = (
                "Getting 'Windows-PowerShell' Log...",
                "win_powershell_log.csv"
            )
        }

        foreach ($Log in $EventLogList.GetEnumerator()) {
            Invoke-ScriptBlock -LogName $Log.Key -Message $Log.Value[0] -OutputFile (Join-Path $EventLogFolder $Log.Value[1])
        }
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    Get-AvailableLogFiles
    Get-AllEventLogs
}
