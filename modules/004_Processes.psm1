function Get-TriageProcessData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProcessFolder
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
    .PARAMETER ProcessFolder
        The directory path where process-related CSV reports will be saved.
    .PARAMETER RunningProcessesCsv
        Optional override path for the raw running processes CSV report.
    .PARAMETER UniqueProcessHashes
        Optional override path for the unique process hashes CSV report.
    .PARAMETER ProcessListOutput
        Optional override path for the structured process list CSV report.
    .PARAMETER EstConnsCsv
        Optional override path for the established network connections CSV report.
    .EXAMPLE
        Get-ProcessAndNetworkReport -ProcessFolder "C:\Triage\Process"

        Runs the collection and generates all four forensic CSV reports.
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
                Join-Path -Path $ProcessFolder -ChildPath "04.01a_running_processes.csv"
            ),
            [string]$UniqueProcessHashes = (
                Join-Path -Path $ProcessFolder -ChildPath "04.01b_unique_process_hashes.csv"
            ),
            [string]$ProcessListOutput = (
                Join-Path -Path $ProcessFolder -ChildPath "04.01c_process_list.csv"
            ),
            [string]$EstConnsCsv = (
                Join-Path -Path $ProcessFolder -ChildPath "04.01d_established_connections.csv"
            )
        )

        # 1. Query WMI/CIM ONCE for all processes
        $Processes = @(Get-CimInstance -ClassName Win32_Process)

        # --- PART 1: Process Listing & Hashing (Files A, B, C) ---

        # Ensure process folder exists
        $null = New-Item -ItemType Directory -Path $ProcessFolder -Force

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
        $ProcessList | Select-Object Proccess_Path, Proccess_Hash -Unique |
            Export-Csv -Path $UniqueProcessHashes -NoTypeInformation -Encoding UTF8

        # Export structured process list
        $ProcessList | Select-Object Proccess_Name, Proccess_Path, Proccess_CommandLine, `
            Proccess_ParentProcessId, Proccess_ProcessId, Proccess_Hash |
            Export-Csv -Path $ProcessListOutput -NoTypeInformation -Encoding UTF8


        # --- PART 2: Established Network Connections (File D) ---

        # Ensure network folder exists
        $null = New-Item -ItemType Directory -Path $NetworkFolder -Force

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
                Join-Path -Path $ProcessFolder -ChildPath "04.02_all_services.csv"
            )
        )
        $Data = Get-CimInstance -ClassName Win32_Service | ForEach-Object {
            $Dll = $null
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
                Description      = $_.Description }
        }
        Write-OutputToCsv -Data ($Data | Sort-Object Name) -OutputFile $CsvFile
    }


    function Get-RunningDriverInfo {
        param(
            [string]$CsvFile = (
                Join-Path -Path $ProcessFolder -ChildPath "04.03_running_driver_query.csv"
            )
        )
        $Data = & (Get-TriageBinary "driverquery") /V /FO CSV | ConvertFrom-Csv
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile

        $Msg = [string]::Format("There were {0} results returned for this function.", $Data.Count)
        Show-Message -Message $Msg -Level INFO -AddToLog
    }


    function Get-SystemDrivers {
        param(
            [string]$CsvFile = (
                Join-Path -Path $ProcessFolder -ChildPath "04.04_system_drivers.csv"
            )
        )
        $Data = Get-CimInstance -ClassName Win32_SystemDriver | Select-Object -Property *
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile

        $Msg = [string]::Format("There were {0} results returned for this function.", $Data.Count)
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

    Invoke-TriageTaskList -Tasks $Tasks -Folder $ProcessFolder

}
