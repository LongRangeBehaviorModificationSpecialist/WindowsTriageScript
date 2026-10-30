function Get-TriageProcessData
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProcessFolder
    )

    begin
    {
        function Get-RunningProcessList
        {
            param(
                [string]$CsvFile = (Join-Path -Path $ProcessFolder -ChildPath "04.01a_running_processes.csv"),
                [string]$UniqueProcessHashOutput = (
                    Join-Path -Path $ProcessFolder -ChildPath "04.01b_unique_process_hashes.csv"
                ),
                [string]$ProcessListOutput = (Join-Path -Path $ProcessFolder -ChildPath "04.01c_process_list.csv")
            )

            $Data = Get-CimInstance -ClassName Win32_Process |
                Select-Object -Property * |
                Sort-Object ParentProcessId -Descending
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
            $ProcessList = @()

            foreach ($Process in (Get-CimInstance -ClassName Win32_Process |
                Select-Object Name, ExecutablePath, CommandLine, ParentProcessId, ProcessId))
            {
                $ProcessObject = New-Object PSCustomObject

                if ($null -ne $Process.ExecutablePath)
                {
                    $Hash = (Get-FileHash -Algorithm SHA256 -Path $Process.ExecutablePath).Hash
                    $ProcessObject |
                        Add-Member -NotePropertyName Proccess_Hash -NotePropertyValue $Hash
                    $ProcessObject |
                        Add-Member -NotePropertyName Proccess_Name -NotePropertyValue $Process.Name
                    $ProcessObject |
                        Add-Member -NotePropertyName Proccess_Path -NotePropertyValue $Process.ExecutablePath
                    $ProcessObject |
                        Add-Member -NotePropertyName Proccess_CommandLine -NotePropertyValue $Process.CommandLine
                    $ProcessObject |
                        Add-Member -NotePropertyName Proccess_ParentProcessId -NotePropertyValue $Process.ParentProcessId
                    $ProcessObject |
                        Add-Member -NotePropertyName Proccess_ProcessId -NotePropertyValue $Process.ProcessId
                    $ProcessList += $ProcessObject
                }
            }

            ($ProcessList | Select-Object Proccess_Path, Proccess_Hash -Unique).GetEnumerator() |
                Export-Csv -Path $UniqueProcessHashOutput -NoTypeInformation -Encoding UTF8

            ($ProcessList |
                Select-Object Proccess_Name, Proccess_Path, Proccess_CommandLine, Proccess_ParentProcessId, Proccess_ProcessId, Proccess_Hash).GetEnumerator() |
                Export-Csv -Path $ProcessListOutput -NoTypeInformation -Encoding UTF8
        }

        function Get-AllServices
        {
            param(
                [string]$CsvFile = (Join-Path -Path $ProcessFolder -ChildPath "04.02_all_services.csv")
            )

            $Data = Get-CimInstance -ClassName Win32_Service | ForEach-Object {
                $Dll = $null
                $Params = "HKLM:\SYSTEM\CurrentControlSet\Services\$( $_.Name )\Parameters"

                if (Test-Path -LiteralPath $Params)
                {
                    $Dll = (Get-ItemProperty -LiteralPath $Params -ErrorAction SilentlyContinue).ServiceDll
                }

                [PSCustomObject]@{
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
                    Description      = $_.Description }
            }
            Write-OutputToCsv -Data ($Data | Sort-Object Name) -OutputFile $CsvFile
        }

        function Get-RunningDriverInfo
        {
            param(
                [string]$CsvFile = (Join-Path -Path $ProcessFolder -ChildPath "04.03_running_driver_query.csv")
            )

            $Data = & (Get-TriageBinary "driverquery") /V /FO CSV | ConvertFrom-Csv
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
            Show-Message -Message "There were $( $Data.Count ) results returned for this function." -AddToLog
        }

        function Get-SystemDrivers
        {
            param(
                [string]$CsvFile = (Join-Path -Path $ProcessFolder -ChildPath "04.04_system_drivers.csv")
            )

            $Data = Get-CimInstance -ClassName Win32_SystemDriver | Select-Object -Property *
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
            Show-Message -Message "There were $( $Data.Count ) results returned for this function." -AddToLog
        }
    }
    process {
    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------
        $Tasks = @(
            @{
                Action  = { Get-RunningProcessList }
                Message = "04.01_Getting Running Processes..."
                Files   = "04.01a_running_processes.csv", "04.01b_unique_process_hashes.csv", "04.01c_process_list.csv"
            }
            @{
                Action  = { Get-AllServices }
                Message = "04.02_Getting All Services..."
                Files   = "04.02_all_services.csv"
            }
            @{
                Action  = { Get-RunningDriverInfo }
                Message = "04.03_Querying Driver Information..."
                Files   = "04.03_running_driver_query.csv"
            }
            @{
                Action  = { Get-SystemDrivers }
                Message = "04.04_Getting System Drivers..."
                Files   = "04.04_system_drivers.csv"
            }
        )
        Invoke-TriageTaskList -Tasks $Tasks -Folder $ProcessFolder
    }
}
