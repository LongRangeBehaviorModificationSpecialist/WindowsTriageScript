function Get-TriageEventLogData {
    [CmdletBinding()]
    param(
        [string]$event_log_folder
    )


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$event_log_name,
            [string]$message,
            [string]$output_file = "$event_log_folder\$output_file"
        )
        try {
            Show-MessageAndWriteLogEntry -Msg $message -Level INFO
            $event_log_path = "C:\Windows\System32\winevt\Logs"
            if (Test-Path -Path (Join-Path -Path $event_log_path -ChildPath (($event_log_name -replace "[/]", "%4") + ".evtx"))) {
                $command = { Get-WinEvent -FilterHashtable @{ Logname = $event_log_name } | Select-Object -Property * | Sort-Object -Property @{ Expression = "TimeCreated"; Descending = $true } }
                $data = &($command)
                Write-OutputToCsv -Data $data -OutputFile $output_file
                Show-MessageAndWriteLogEntry -File $output_file -Level SUCCESS
            }
            else {
                $file_not_found_msg = "Event Log `"$event_log_name`" was not found in `"$event_log_path`""
                Show-MessageAndWriteLogEntry -Msg $file_not_found_msg -Level WARNING
                continue
            }
        }
        catch {
            $error_msg = "Execution failed during `"$($MyInvocation.MyCommand.Name)`". Error: $($_.Exception.Message)"
            Show-MessageAndWriteLogEntry -Msg $error_msg -Level ERROR
        }
    }


    function Get-AvailableLogFiles {
        param(
            [string]$output_file = "$event_log_folder\available_log_files.txt"
        )
        $begin_msg = "Gathering list of available Event Log files..."
        Show-MessageAndWriteLogEntry -Msg $begin_msg -Level INFO
        $command =  { Get-WinEvent -ListLog * |
                        Where-Object { $_.IsEnabled } |
                        Select-Object LogName, RecordCount, FileSize, LogMode, LogFilePath, LastWriteTime |
                        Sort-Object -Property @{ Expression = "RecordCount"; Descending = $true }
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
        Show-MessageAndWriteLogEntry -File $output_file -Level SUCCESS
    }


    function Get-AllEventLogs {
        param()
        $event_log_list = [ordered]@{
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

        foreach ($log in $event_log_list.GetEnumerator()) {
            Invoke-ScriptBlock -EventLogName $log.key -Msg $task.value[0] -OutputFile $task.value[1]
        }
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    Get-AvailableLogFiles
    Get-AllEventLogs
}
