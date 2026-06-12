function Get-TriageProcessData {
    [CmdletBinding()]
    param(
        [string]$processFolder
    )


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$action,
            [string]$functionMsg,
            [string]$outputFile
        )
        try {
            Show-MessageAndWriteLogEntry -Message $functionMsg -Level INFO
            & $action
            Show-MessageAndWriteLogEntry -File $outputFile -Level SUCCESS
        }
        catch {
            $errorMessage = "Execution failed during '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
            Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
        }
    }


    function Get-RunningProcessList {
        param(
            [string]$outputFile = "$processFolder\running_processes.txt",
            [string]$csvOutputFile = "$processFolder\running_processes.csv",
            [string]$uniqueProcessHashOutput = "$processFolder\unique_process_hashes.csv",
            [string]$processListOutput = "$processFolder\process_list.csv"
        )
        $command = { Get-CimInstance -ClassName Win32_Process | Select-Object -Property * | Sort-Object ParentProcessId -Desc }
        $data = &($command)
        Save-OutputAsCsv -Data $data -OutputFile $csvOutputFile
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
        $processes_list = @()

        foreach ($process in (Get-WmiObject Win32_Process | Select-Object Name, ExecutablePath, CommandLine, ParentProcessId, ProcessId)) {
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
        ($processes_list | Select-Object Proc_Path, Proc_Hash -Unique).GetEnumerator() | Export-Csv -NoTypeInformation -Path $uniqueProcessHashOutput
        ($processes_list | Select-Object Proc_Name, Proc_Path, Proc_CommandLine, Proc_ParentProcessId, Proc_ProcessId, Proc_Hash).GetEnumerator() | Export-Csv -NoTypeInformation -Path $processListOutput
    }


    function Get-SvcHostsAndProcess {
        param(
            [string]$outputFile = "$processFolder\svc_host_and_processes.txt"
        )
        $command = { Get-CimInstance -ClassName Win32_Process | Where-Object { $_.name -eq "svchost.exe" } | Select-Object ProcessId | ForEach-Object { $p = $_.ProcessID; Get-CimInstance -ClassName Win32_Service | Where-Object { $_.processId -eq $p } | Select-Object ProcessID, Name, DisplayName, State, ServiceType, StartMode, PathName, Status } }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-RunningServices {
        param(
            [string]$outputFile = "$processFolder\running_services.txt",
            [string]$csvOutputFile = "$processFolder\running_services.csv"
        )
        $command = { Get-CimInstance -ClassName Win32_Service | Select-Object -Property * | Sort-Object State }
        $data = &($command)
        Save-OutputAsCsv -Data $data -OutputFile $csvOutputFile
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-RunningDriverInfo {
        param(
            [string]$outputFile = "$processFolder\driver_query.csv"
        )
        $command = { driverquery.exe /v /FO CSV }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-SystemDrivers {
        param(
            [string]$csvOutputFile = "$processFolder\system_drivers.csv"
        )
        $command = { Get-WMIObject -Class Win32_SystemDriver | Select-Object -Property * }
        $data = &($command)
        Save-OutputAsCsv -Data $data -OutputFile $csvOutputFile
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $workFlow = [ordered]@{
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
    }

    foreach ($task in $workFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
