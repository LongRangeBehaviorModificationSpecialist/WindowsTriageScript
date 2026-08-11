function Get-TriageEventLogData {
    [CmdletBinding()]
    param(
        [string]$EventLogFolder
    )


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$EventLogName,
            [string]$Message,
            [string]$OutputFile = "$EventLogFolder\$OutputFile"
        )
        try {
            Show-MessageAndWriteLogEntry -Msg $Message -Level INFO
            $EventLogPath = "C:\Windows\System32\winevt\Logs"
            if (Test-Path -Path (Join-Path -Path $EventLogPath -ChildPath (($EventLogName -replace "[/]", "%4") + ".evtx"))) {
                $Command =  { Get-WinEvent -FilterHashtable @{ Logname = $EventLogName } |
                                Select-Object -Property * |
                                Sort-Object -Property @{ Expression = "TimeCreated"; Descending = $true } }
                $Data = &($Command)
                Write-OutputToCsv -Data $Data -OutputFile $OutputFile
                Show-MessageAndWriteLogEntry -File $OutputFile -Level SUCCESS
            }
            else {
                $FileNotFoundMsg = "Event Log '$EventLogName' was not found in '$EventLogPath'"
                Show-MessageAndWriteLogEntry -Msg $FileNotFoundMsg -Level WARNING
                continue
            }
        }
        catch {
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error: $( $_.Exception.Message )"
            Show-MessageAndWriteLogEntry -Msg $ErrorMsg -Level ERROR
        }
    }


    function Get-AvailableLogFiles {
        param(
            [string]$OutputFile = "$EventLogFolder\available_log_files.txt"
        )
        $BeginMsg = "Gathering list of available Event Log files..."
        Show-MessageAndWriteLogEntry -Msg $BeginMsg -Level INFO
        $Command =  { Get-WinEvent -ListLog * |
                        Where-Object { $_.IsEnabled } |
                        Select-Object LogName, RecordCount, FileSize, LogMode, LogFilePath, LastWriteTime |
                        Sort-Object -Property @{ Expression = "RecordCount"; Descending = $true }
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
        Show-MessageAndWriteLogEntry -File $OutputFile -Level SUCCESS
    }


    function Get-AllEventLogs {
        param()
        $EventLogList = [ordered]@{
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

        foreach ($Log in $EventLogList.GetEnumerator()) {
            Invoke-ScriptBlock -EventLogName $Log.key -Msg $Task.value[0] -OutputFile $Task.value[1]
        }
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    Get-AvailableLogFiles
    Get-AllEventLogs
}
