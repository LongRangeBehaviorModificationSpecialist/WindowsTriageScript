function Get-TriageProcessData {
    <#
    .SYNOPSIS
        Lists running processes with the hash of each program, plus services
        and drivers (module 004_Processes).

    .DESCRIPTION
        Runs a series of read-only collection tasks and writes the results to
        the module folder:

            04.01a_running_processes.csv,
            04.01b_unique_process_hashes.csv,
            04.01c_process_list.csv,
            04.01d_established_connections.csv
                (a) Every property of every running process (`Win32_Process`),
                    sorted by parent process ID, highest first.
                (b) The distinct path and hash pairs from the process list,
                    so a program that runs many times (such as `svchost.exe`)
                    appears once,
                (c) For each process that has an executable path: name, path,
                    command line, parent process ID, process ID, and the
                    SHA256 hash of the executable file.
                (d) Established connections from netstat, each matched to the
                    owning process name, path, command line, and start time.
            04.02  all_services.csv
                All services (`Win32_Service`), sorted by name.  For services
                hosted in a shared process, the service DLL is read from the
                service's registry Parameters key and added to the record.
            04.03  running_driver_query.csv
                Output of `driverquery /V` in CSV form.
            04.04  system_drivers.csv
                Installed system drivers (`Win32_SystemDriver`).

        Processes with no executable path (such as System and Idle) do not
        appear in `04.01b_unique_process_hashes.csv` or
        `04.01c_process_list.csv`, but they are in
        `04.01a_running_processes.csv`.

        The column names in those two files begin with "Proccess_" (spelled
        that way in the code); keep this in mind when writing scripts that
        read the files.

        This module lists processes.

        To save the memory of processes, use `Get-RunningProcesses`.

    .PARAMETER ProcessesFolder
        Path of the folder where this module writes its files.

        `Invoke-DfirTriageScan creates it as `<ResultsFolder>\004_Process`.

    .INPUTS
        None.

        This function does not accept pipeline input.

    .OUTPUTS
        None.

        Results are written to files in ProcessesFolder, and progress
        is written to the screen and the log.

    .EXAMPLE
        Get-TriageProcessData `
            -ProcessesFolder "E:\Triage\Case-2026-0142\004_Process"

        Writes the 04.xx files into that folder.

    .EXAMPLE
        Invoke-DfirTriageScan -ResultsFolder $Folder -Operator "J. Smith" `
            -CaseNumber "2026-0142" -Modules "004_Process"

        The usual way this module runs, on its own.

    .NOTES
        Requires an elevated session so that every process's executable can
        be read.

        The `driverquery` copy from bin is found with `Get-TriageBinary`,
        which only works after `Initialize-TriageSystemTools` has run, so
        call this function through `Invoke-DfirTriageScan`.

        Hashing reads the file of every running program, which takes time
        on a busy computer.

        The process list is a snapshot: processes that start or stop while
        the task runs may differ between `04.01a_running_processes.csv` and
        `04.01c_process_list.csv`, because each is read separately.

        An executable that cannot be read is the usual cause of a failed
        04.01 task, since an error during hashing stops that task.

        Wrapping the hash step in try/catch (leaving the hash empty) keeps
        the rest of the data.

        Each task is isolated: if one fails, the error is logged and the next
        task still runs.

        A task whose output file is missing or empty is also reported as an
        error.

    .LINK
        Invoke-DfirTriageScan

    .LINK
        Get-RunningProcesses

    .LINK
        Invoke-TriageTaskList
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProcessesFolder
    )

    function Get-ProcessAndNetworkReport {
    <#
    .SYNOPSIS
        Gathers a comprehensive forensic snapshot of running processes, calculates process executable hashes,
        and correlates active network connections with their parent processes.
    .DESCRIPTION
        Queries Win32_Process once to eliminate redundant CIM overhead. It exports raw process listings,
        unique process path/hash mappings, structured process details, and established network connection mappings
        into their respective output folders and files.
    .PARAMETER RunningProcessesCsv
        Optional override path for the raw running processes CSV report.
    .PARAMETER UniqueProcessHashes
        Optional override path for the unique process hashes CSV report.
    .PARAMETER ProcessListOutput
        Optional override path for the structured process list CSV report.
    .PARAMETER EstConnsCsv
        Optional override path for the established network connections CSV report.
    .INPUTS
        None
    .OUTPUTS
        None
    .NOTES
        N/A
    #>
        [OutputType([void])]
        param(
            [string]$RunningProcessesCsv = (
                Join-Path -Path $ProcessesFolder -ChildPath "04.01a_running_processes.csv"
            ),
            [string]$UniqueProcessHashes = (
                Join-Path -Path $ProcessesFolder -ChildPath "04.01b_unique_process_hashes.csv"
            ),
            [string]$ProcessListOutput = (
                Join-Path -Path $ProcessesFolder -ChildPath "04.01c_process_list.csv"
            ),
            [string]$EstConnsCsv = (
                Join-Path -Path $ProcessesFolder -ChildPath "04.01d_established_connections.csv"
            )
        )

        # 1. Query WMI/CIM ONCE for all processes
        $Processes = @(Get-CimInstance -ClassName Win32_Process)

        # --- PART 1: Process Listing & Hashing (Files A, B, C) ---

        # Ensure process folder exists
        # $null = New-Item -ItemType Directory -Path $ProcessesFolder -Force

        # Export raw processes sorted by parent PID
        Write-OutputToCsv -Data ($Processes |
            Select-Object -Property * |
            Sort-Object ParentProcessId -Descending) `
            -OutputFile $RunningProcessesCsv

        $HashCache   = @{}
        $ProcessList = foreach ($Process in $Processes) {
            if ($null -eq $Process.ExecutablePath) {
                continue
            }
            if (-not $HashCache.ContainsKey($Process.ExecutablePath)) {
                $HashCache[$Process.ExecutablePath] = try {
                    (Get-StreamHash -LiteralPath $Process.ExecutablePath -IncludeMd5:$false).SHA256
                }
                catch {
                    $null
                }
            }
            [PSCustomObject]@{
                Proccess_Hash            = $HashCache[$Process.ExecutablePath]
                Proccess_Name            = $Process.Name
                Proccess_Path            = $Process.ExecutablePath
                Proccess_CommandLine     = $Process.CommandLine
                Proccess_ParentProcessId = $Process.ParentProcessId
                Proccess_ProcessId       = $Process.ProcessId
            }
        }

        # Export unique hashes
        $ProcessList | Select-Object Proccess_Path, Proccess_Hash -Unique | Export-Csv -Path $UniqueProcessHashes -NoTypeInformation -Encoding UTF8

        # Export structured process list
        $ProcessList | Select-Object Proccess_Name, Proccess_Path, Proccess_CommandLine, Proccess_ParentProcessId, Proccess_ProcessId, Proccess_Hash | Export-Csv -Path $ProcessListOutput -NoTypeInformation -Encoding UTF8


        # --- PART 2: Established Network Connections (File D) ---

        # # Ensure network folder exists
        # $null = New-Item -ItemType Directory -Path $ProcessesFolder -Force

        # Build a fast PID lookup hashtable from our already-retrieved $Processes collection
        $ProcsLookup = @{}
        foreach ($P in $Processes) {
            $ProcsLookup[[int]$P.ProcessId] = $P
        }

        $ConnectionData = & (Get-TriageBinary "netstat") -nao |
            Select-String "ESTABLISHED" |
            ForEach-Object {
                # Proto, Local, Remote, State, PID
                $F = ($_.Line -split "\s+") | Where-Object { $_ }
                $P = $ProcsLookup[[int]$F[4]]
                [PSCustomObject]@{
                    Local       = $F[1]
                    Remote      = $F[2]
                    PID         = $F[4]
                    ProcessName = $P.Name
                    Path        = $P.ExecutablePath
                    CommandLine = $P.CommandLine
                    Created     = $P.CreationDate
                }
            }

        Write-OutputToCsv -Data $ConnectionData -OutputFile $EstConnsCsv
    }


    function Get-AllServices {
        param(
            [string]$CsvFile = (
                Join-Path -Path $ProcessesFolder -ChildPath "04.02_all_services.csv"
            )
        )
        $Data = Get-CimInstance -ClassName Win32_Service | ForEach-Object {
            $Dll    = $null
            $Params = "HKLM:\SYSTEM\CurrentControlSet\Services\$( $_.Name )\Parameters"

            if (Test-Path -LiteralPath $Params) {
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
                Description      = $_.Description
            }
        }
        Write-OutputToCsv -Data ($Data | Sort-Object Name) -OutputFile $CsvFile
    }


    function Get-RunningDriverInfo {
        param(
            [string]$CsvFile = (
                Join-Path -Path $ProcessesFolder -ChildPath "04.03_running_driver_query.csv"
            )
        )
        $Data = & (Get-TriageBinary "driverquery") /V /FO CSV | ConvertFrom-Csv
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile

        $Msg = ('There were {0} results returned for this function.' -f $Data.Count)
        Show-Message -Message $Msg -Level INFO -AddToLog
    }


    function Get-SystemDrivers {
        param(
            [string]$CsvFile = (
                Join-Path -Path $ProcessesFolder -ChildPath "04.04_system_drivers.csv"
            )
        )
        $Data = Get-CimInstance -ClassName Win32_SystemDriver | Select-Object -Property *
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile

        $Msg = ('There were {0} results returned for this function.' -f $Data.Count)
        Show-Message -Message $Msg -Level INFO -AddToLog
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $Tasks = @(
        @{
            Action    = { Get-ProcessAndNetworkReport }
            Message   = "04.01_Getting Running Processes and Connections..."
            Files     = "04.01a_running_processes.csv",
                        "04.01b_unique_process_hashes.csv",
                        "04.01c_process_list.csv",
                        "04.01d_established_connections.csv"
        }
        @{
            Action    = { Get-AllServices }
            Message   = "04.02_Getting All Services..."
            Files     = "04.02_all_services.csv"
        }
        @{
            Action    = { Get-RunningDriverInfo }
            Message   = "04.03_Querying Driver Information..."
            Files     = "04.03_running_driver_query.csv"
        }
        @{
            Action    = { Get-SystemDrivers }
            Message   = "04.04_Getting System Drivers..."
            Files     = "04.04_system_drivers.csv"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $ProcessesFolder

}
