function Get-TriageProcessData {
    [CmdletBinding()]
    param(
        [string]$process_folder
    )


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$action,
            [string]$function_msg,
            [string]$output_file
        )
        try {
            Show-MessageAndWriteLogEntry -Msg $function_msg -Level INFO
            & $action
            Show-MessageAndWriteLogEntry -File $output_file -Level SUCCESS
        }
        catch {
            $error_msg = "Execution failed during `"$($MyInvocation.MyCommand.Name)`". Error: $($_.Exception.Message)"
            Show-MessageAndWriteLogEntry -Msg $error_msg -Level ERROR
        }
    }


    function Get-RunningProcessList {
        param(
            [string]$output_file                = "$process_folder\running_processes.txt",
            [string]$csv_output_file            = "$process_folder\running_processes.csv",
            [string]$unique_process_hash_output = "$process_folder\unique_process_hashes.csv",
            [string]$process_list_output        = "$process_folder\process_list.csv"
        )
        $command =  { Get-CimInstance -ClassName Win32_Process |
                        Select-Object -Property * |
                        Sort-Object ParentProcessId -Descending
                    }
        $data = &($command)
        Write-OutputToCsv -Data $data -OutputFile $csv_output_file
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
        $processes_list = @()

        foreach ($process in (Get-CimInstance -ClassName Win32_Process | Select-Object Name, ExecutablePath, CommandLine, ParentProcessId, ProcessId)) {
            $process_obj = New-Object PSCustomObject
            if ($null -ne $process.ExecutablePath) {
                $hash = (Get-FileHash -Algorithm SHA256 -Path $process.ExecutablePath).Hash
                $process_obj | Add-Member -NotePropertyName Proc_Hash -NotePropertyValue $hash
                $process_obj | Add-Member -NotePropertyName Proc_Name -NotePropertyValue $process.Name
                $process_obj | Add-Member -NotePropertyName Proc_Path -NotePropertyValue $process.ExecutablePath
                $process_obj | Add-Member -NotePropertyName Proc_CommandLine -NotePropertyValue $process.CommandLine
                $process_obj | Add-Member -NotePropertyName Proc_ParentProcessId -NotePropertyValue $process.ParentProcessId
                $process_obj | Add-Member -NotePropertyName Proc_ProcessId -NotePropertyValue $process.ProcessId
                $processes_list += $process_obj
            }
        }
        ($processes_list | Select-Object Proc_Path, Proc_Hash -Unique).GetEnumerator() | Export-Csv -NoTypeInformation -Path $unique_process_hash_output
        ($processes_list | Select-Object Proc_Name, Proc_Path, Proc_CommandLine, Proc_ParentProcessId, Proc_ProcessId, Proc_Hash).GetEnumerator() | Export-Csv -NoTypeInformation -Path $process_list_output
    }


    function Get-SvcHostsAndProcess {
        param(
            [string]$output_file = "$process_folder\svc_host_and_processes.txt"
        )
        $command =  { Get-CimInstance -ClassName Win32_Process |
                        Where-Object { $_.name -eq "svchost.exe" } |
                        Select-Object ProcessId |
                        ForEach-Object { $p = $_.ProcessID; Get-CimInstance -ClassName Win32_Service |
                            Where-Object {
                                $_.processId -eq $p } |
                                Select-Object ProcessID, Name, DisplayName, State, ServiceType, StartMode, PathName, Status }
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-RunningServices {
        param(
            [string]$output_file     = "$process_folder\running_services.txt",
            [string]$csv_output_file = "$process_folder\running_services.csv"
        )
        $command =  { Get-CimInstance -ClassName Win32_Service |
                        Where-Object State -eq "Running" |
                        Select-Object -Property * |
                        Sort-Object -Property Name
                    }
        $data = &($command)
        Write-OutputToCsv -Data $data -OutputFile $csv_output_file
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
        $result_count = ($command).Count
        Show-MessageAndWriteLogEntry -Msg "There were $($result_count) results returned for this function."
    }


    function Get-RunningDriverInfo {
        param(
            [string]$output_file = "$process_folder\driver_query.csv"
        )
        $command =  { driverquery.exe /v /FO CSV }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
        $result_count = ($command).Count
        Show-MessageAndWriteLogEntry -Msg "There were $($result_count) results returned for this function."
    }


    function Get-SystemDrivers {
        param(
            [string]$csv_output_file = "$process_folder\system_drivers.csv"
        )
        $command =  { Get-CimInstance -ClassName Win32_SystemDriver |
                        Select-Object -Property *
                    }
        $data = &($command)
        Write-OutputToCsv -Data $data -OutputFile $csv_output_file
        $result_count = ($command).Count
        Show-MessageAndWriteLogEntry -Msg "There were $($result_count) results returned for this function."

    }


    function Get-PnPSignedDrivers {
        param(
            [string]$output_file = "$connected_devices_folder\pnp_signed_drivers.csv"
        )
        $command =  { Get-CimInstance -ClassName Win32_PnPSignedDriver |
                        Select-Object -Property *
        }
        $data = &($command)
        Write-OutputToCsv -Data $data -OutputFile $output_file
        $result_count = ($command).Count
        Show-MessageAndWriteLogEntry -Msg "There were $($result_count) results returned for this function."
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $process_work_flow = [ordered]@{
        { Get-RunningProcessList } = (
            "Getting Running Processes...",
            "[running_processes.txt, running_processes.csv, unique_process_hashes.csv, process_list.csv]"
        )
        { Get-RunningProcessList } = (
            "Getting SVCHost & Associated Process...",
            "svc_host_and_processes.txt"
        )
        { Get-RunningServices } = (
            "Getting Running Services...",
            "[running_services.txt, running_services.csv]"
        )
        { Get-RunningDriverInfo } = (
            "Querying Driver Information...",
            "driver_query.csv"
        )
        { Get-SystemDrivers } = (
            "Getting System Drivers...",
            "system_drivers.csv"
        )
        { Get-PnPSignedDrivers } = (
            "Gathering Driver Info for PnP Devices...",
            "pnp_signed_drivers.csv"
        )
    }

    foreach ($task in $process_work_flow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
