function Get-TriageProcessData {
    [CmdletBinding()]

    param([string]$ProcessFolder)

    function Invoke-ScriptBlock {
        param(
            [scriptblock]$Action,
            [string]$FunctionMessage,
            [string]$OutputFile
        )
        try {
            Show-Message -Message $FunctionMessage -Level INFO -AddToLog
            & $Action
            Show-Message -File $OutputFile -Level SUCCESS -AddToLog
        }
        catch {
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error => $( $_.Exception.Message )"
            Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
        }
    }

    function Get-RunningProcessList {
        param(
            [string]$OutputFile = "$ProcessFolder\running_processes.txt",
            [string]$CsvOutputFile = "$ProcessFolder\running_processes.csv",
            [string]$UniqueProcessHashOutput = "$ProcessFolder\unique_process_hashes.csv",
            [string]$ProcessListOutput = "$ProcessFolder\process_list.csv"
        )
        $Command = { Get-CimInstance -ClassName Win32_Process | Select-Object -Property * | Sort-Object ParentProcessId -Descending }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $CsvOutputFile
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
        $ProcessList = @()

        foreach ($Process in (Get-CimInstance -ClassName Win32_Process | Select-Object Name, ExecutablePath, CommandLine, ParentProcessId, ProcessId)) {
            $ProcessObject = New-Object PSCustomObject
            if ($null -ne $Process.ExecutablePath) {
                $Hash = (Get-FileHash -Algorithm SHA256 -Path $Process.ExecutablePath).Hash
                $ProcessObject | Add-Member -NotePropertyName Proc_Hash -NotePropertyValue $Hash
                $ProcessObject | Add-Member -NotePropertyName Proc_Name -NotePropertyValue $Process.Name
                $ProcessObject | Add-Member -NotePropertyName Proc_Path -NotePropertyValue $Process.ExecutablePath
                $ProcessObject | Add-Member -NotePropertyName Proc_CommandLine -NotePropertyValue $Process.CommandLine
                $ProcessObject | Add-Member -NotePropertyName Proc_ParentProcessId -NotePropertyValue $Process.ParentProcessId
                $ProcessObject | Add-Member -NotePropertyName Proc_ProcessId -NotePropertyValue $Process.ProcessId
                $ProcessList += $ProcessObject
            }
        }
        ($ProcessList | Select-Object Proc_Path, Proc_Hash -Unique).GetEnumerator() | Export-Csv -NoTypeInformation -Path $UniqueProcessHashOutput -Encoding UTF8
        ($ProcessList | Select-Object Proc_Name, Proc_Path, Proc_CommandLine, Proc_ParentProcessId, Proc_ProcessId, Proc_Hash).GetEnumerator() | Export-Csv -NoTypeInformation -Path $ProcessListOutput -Encoding UTF8
    }

    function Get-SvcHostsAndProcess {
        param([string]$OutputFile = "$ProcessFolder\svc_host_and_processes.txt")
        $Command =  { Get-CimInstance -ClassName Win32_Process |
                        Where-Object { $_.name -eq "svchost.exe" } |
                        Select-Object ProcessId |
                        ForEach-Object { $P = $_.ProcessID; Get-CimInstance -ClassName Win32_Service |
                        Where-Object { $_.processId -eq $P } |
                        Select-Object ProcessID, Name, DisplayName, State, ServiceType, StartMode, PathName, Status } }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-RunningServices {
        param(
            [string]$OutputFile    = "$ProcessFolder\running_services.txt",
            [string]$CsvOutputFile = "$ProcessFolder\running_services.csv"
        )
        $Command = { Get-CimInstance -ClassName Win32_Service | Where-Object State -eq "Running" | Select-Object -Property * | Sort-Object -Property Name }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $CsvOutputFile
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
        $ResultCount = ($Data).Count
        Show-Message -Message "There were $ResultCount results returned for this function." -AddToLog
    }

    function Get-RunningDriverInfo {
        param([string]$OutputFile = "$ProcessFolder\driver_query.csv")
        $Command = { driverquery.exe /v /FO CSV }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
        $ResultCount = ($Data).Count
        Show-Message -Message "There were $ResultCount results returned for this function." -AddToLog
    }

    function Get-SystemDrivers {
        param([string]$CsvOutputFile = "$ProcessFolder\system_drivers.csv")
        $Command = { Get-CimInstance -ClassName Win32_SystemDriver | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $CsvOutputFile
        $ResultCount = ($Data).Count
        Show-Message -Message "There were $ResultCount results returned for this function." -AddToLog

    }




    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $ProcessWorkFlow = [ordered]@{
        { Get-RunningProcessList } = (
            "Getting Running Processes...",
            "[running_processes.txt, running_processes.csv, unique_process_hashes.csv, process_list.csv]"
        )
        { Get-SvcHostsAndProcess } = (
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

    foreach ($Task in $ProcessWorkFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $Task.key -FunctionMessage $Task.value[0] -OutputFile $Task.value[1]
    }
}
