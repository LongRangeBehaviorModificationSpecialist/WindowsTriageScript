function Get-TriageProcessData {
    [CmdletBinding()]
    param(
        [string]$ProcessFolder
    )

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

    function Get-AllServices {
        param(
            [string]$OutputFile = "$ProcessFolder\all_services.csv"
        )
        $Data = Get-CimInstance -ClassName Win32_Service | ForEach-Object {
            $Dll = $null
            $Params = "HKLM:\SYSTEM\CurrentControlSet\Services\$( $_.Name )\Parameters"
            if (Test-Path -LiteralPath $Params) {
                $Dll = (Get-ItemProperty -LiteralPath $Params -ErrorAction SilentlyContinue).ServiceDll
            }
            [pscustomobject]@{
                Name             = $_.Name
                DisplayName      = $_.DisplayName
                State            = $_.State
                StartMode        = $_.StartMode
                DelayedAutoStart = $_.DelayedAutoStart
                StartName        = $_.StartName
                ServiceType      = $_.ServiceType
                ProcessId        = $_.ProcessId
                PathName         = $_.PathName
                ServiceDll       = $Dll
                Description      = $_.Description
            }
        }
        Write-OutputToCsv -Data ($Data | Sort-Object Name) -OutputFile $OutputFile
    }

    function Get-RunningDriverInfo {
        param(
            [string]$OutputFile = "$ProcessFolder\driver_query.csv"
        )
        $Command = { & (Get-TriageBinary "driverquery") .exe /v /FO CSV }
        $Data = &($Command)
        Set-Content -Path $OutputFile -Value $Data -Encoding UTF8
        Show-Message -Message "There were $( $Data.Count ) results returned for this function." -AddToLog
    }

    function Get-SystemDrivers {
        param(
            [string]$OutputFile = "$ProcessFolder\system_drivers.csv"
        )
        $Command = { Get-CimInstance -ClassName Win32_SystemDriver | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
        Show-Message -Message "There were $( $Data.Count ) results returned for this function." -AddToLog
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $Tasks = @(
        @{
            Action  = { Get-RunningProcessList }
            Message = "Getting Running Processes..."
            Files   = "running_processes.txt", "running_processes.csv", "unique_process_hashes.csv", "process_list.csv"
        }
        @{
            Action = { Get-AllServices }
            Message = "Getting All Services..."
            Files = "all_services.csv"
        }
        @{
            Action  = { Get-RunningDriverInfo }
            Message = "Querying Driver Information..."
            Files   = "driver_query.csv"
        }
        @{
            Action  = { Get-SystemDrivers }
            Message = "Getting System Drivers..."
            Files   = "system_drivers.csv"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $ProcessFolder
}
