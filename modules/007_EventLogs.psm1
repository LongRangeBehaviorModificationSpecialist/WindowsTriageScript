function Get-TriageEventLogData {
    [CmdletBinding()]
    param(
        [string]$eventLogFolder
    )


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$eventLogName,
            [string]$message,
            [string]$outputFile = "$eventLogFolder\$outputFile"
        )
        try {
            Show-MessageAndWriteLogEntry -Message $message -Level INFO
            $eventLogPath = "C:\Windows\System32\winevt\Logs"
            if (Test-Path -Path (Join-Path -Path $eventLogPath -ChildPath (($eventLogName -replace "[/]", "%4") + ".evtx"))) {
                $command = { Get-WinEvent -FilterHashtable @{ Logname = $eventLogName } | Select-Object -Property * | Sort-Object -Property @{ Expression = "TimeCreated"; Descending = $true } }
                $data = &($command)
                Save-OutputAsCsv -Data $data -OutputFile $outputFile
                Show-MessageAndWriteLogEntry -File $outputFile -Level SUCCESS
            }
            else {
                $fileNotFoundMsg = "The Event Log '$eventLogName' was not found in '$eventLogPath'"
                Show-MessageAndWriteLogEntry -Message $fileNotFoundMsg -Level WARNING
                continue
            }
        }
        catch {
            $errorMessage = "Execution failed during '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
            Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
        }
    }


    function Get-AvailableLogFiles {
        param(
            [string]$outputFile = "$eventLogFolder\available_log_files.txt"
        )
        $beginMsg = "Gathering list of available Event Log files..."
        Show-MessageAndWriteLogEntry -Message $beginMsg -Level INFO
        $command = { Get-WinEvent -ListLog * | Where-Object { $_.IsEnabled } | Select-Object LogName, RecordCount, FileSize, LogMode, LogFilePath, LastWriteTime | Sort-Object -Property @{ Expression = "RecordCount"; Descending = $true } }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
        Show-MessageAndWriteLogEntry -File $outputFile -Level SUCCESS
    }


    function Get-AllEventLogs {
        param()
        $logList = [ordered]@{
            "Application" = (
                "Getting 'Application' Log...",
                "application_log.csv"
            )
            "Microsoft-Windows-Application-Experience/Program-Inventory" = (
                "Getting 'Windows-Application-Experience/Program Inventory' Log...",
                "win_application_experience_program_inventory_log.csv"
            )
            "Microsoft-Windows-DriverFrameworks-UserMode/Operational" = (
                "Getting 'Windows-DriverFrameworks-UserMode/Operational' Log...",
                "win_driveframeworks_usermode_operational_log.csv"
            )
            "Microsoft-Windows-Partition/Diagnostic" = (
                "Getting 'Microsoft-Windows-Partition/Diagnostic' Log...",
                "win_partition_diagnostic_log.csv"
            )
            "Microsoft-Windows-PowerShell/Admin" = (
                "Getting 'Microsoft-Windows-PowerShell/Admin' Log...",
                "win_powershell_admin_log.csv"
            )
            "Microsoft-Windows-PowerShell/Operational" = (
                "Getting 'Microsoft-Windows-PowerShell/Operational' Log...",
                "win_powershell_operational_log.csv"
            )
            "Microsoft-Windows-Sysmon/Operational" = (
                "Getting Microsoft-Windows-Sysmon/Operational Log...",
                "win_sysmon_operational_log.csv"
            )
            "Microsoft-Windows-TaskScheduler/Operational" = (
                "Getting 'Microsoft-Windows-TaskScheduler/Operational' Log...",
                "win_taskscheduler_operational_log.csv"
            )
            "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" = (
                "Getting 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational' Log...",
                "windows_terminalservices_localsessionmanager_operational_log.csv"
            )
            "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational" = (
                "Getting 'Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational' Log...",
                "win_terminalservices_remoteconnectionmanager_operational_log.csv"
            )
            "Microsoft-Windows-TerminalServices-RDPClient/Operational" = (
                "Getting 'Microsoft-Windows-TerminalServices-RDPClient/Operational' Log...",
                "win_terminalservices_rdpclient_operational_log.csv"
            )
            "Microsoft-Windows-Windows Defender/Operational" = (
                "Getting 'Microsoft-Windows-Windows Defender/Operational' Log...",
                "win_windows_defender_operational_log.csv"
            )
            "Microsoft-Windows-Windows Defender/WHC" = (
                "Getting 'Microsoft-Windows-Windows Defender/WHC' Log...",
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

        foreach ($log in $logList.GetEnumerator()) {
            Invoke-ScriptBlock -EventLogName $log.key -Message $task.value[0] -OutputFile $task.value[1]
        }
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    Get-AvailableLogFiles
    Get-AllEventLogs
}
