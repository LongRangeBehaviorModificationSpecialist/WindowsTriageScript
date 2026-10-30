function Get-TriageDeviceData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DeviceFolder
    )
    begin {

        function Get-MiscDeviceData {
            param (
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "01.01_device_info.txt")
            )
            $Data = Get-ComputerDetails
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-SystemProcesses {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "01.02_PS_info.txt")
            )

            & (Get-TriageBinary "PSInfo") -accepteula -s -h -d > $TxtFile 2>&1

            $Msg = "`n`nPsInfo was run with `-accepteula`, which creates `HKCU\Software\Sysinternals\PsInfo\EulaAccepted (DWORD = 1)` in the `NTUSER.DAT` of the account used to run the tool (<DOMAIN\user>). This change was made by the examiner's tool, not by the subject. In the current execution order, the snapshot of that account's registry hive is taken before PsInfo runs, so the collected copy will not contain the value."

            Add-Content -Path $TxtFile -Value $Msg -Encoding UTF8
        }

        function Get-FullFileList {
            param(
                [string]$CsvFile = (Join-Path -Path $DeviceFolder -ChildPath "01.03_full_dir_list.csv")
            )
            Get-ChildItem -LiteralPath "$env:SystemDrive\" -Recurse -Force -ErrorAction SilentlyContinue |
                Select-Object FullName, Length, Attributes, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc |
                Export-Csv -LiteralPath $CsvFile -NoTypeInformation -Encoding UTF8
        }

        function Get-CurrentComputerInfo {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "01.04_computer_info.txt")
            )
            $Data = Get-ComputerInfo
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-SystemInfo1 {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "01.05_system_info1.txt")
            )
            $Data = & (Get-TriageBinary "systeminfo") /FO LIST
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-SystemInfo2 {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "01.06_system_info2.txt")
            )
            $Data = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -Property *
            Write-OutputToFile -Data $Data -OutputFile $TxtFile -Append
        }

        function Get-PhysicalMemory {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "01.07_physical_memory.txt")
            )
            $Data = Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object -Property *
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-EnvVars {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "01.08_env_vars.txt")
            )
            $Data = Get-ChildItem -LiteralPath env: | Format-List
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-DiskPart {
            param(
                [string]$CsvFile = (Join-Path -Path $DeviceFolder -ChildPath "01.09_disk_partitions.csv")
            )
            $Data = Get-CimInstance -ClassName Win32_DiskPartition | Select-Object -Property * | Sort-Object -Property Name
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-UserAccounts {
            param(
                [string]$CsvFile = (Join-Path -Path $DeviceFolder -ChildPath "01.10_user_accounts.csv")
            )
            $Data = Get-CimInstance -ClassName Win32_UserProfile | Select-Object *, @{ N = "last used"; E = { $_.lastusetime } }
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-LogonSessions {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "01.11_logon_sessions.txt")
            )
            $Data = Get-CimInstance -ClassName Win32_LogonSession | Select-Object -Property *
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-StartUpApps {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "01.12_start_up_apps.txt"),
                [string]$CsvFile = (Join-Path -Path $DeviceFolder -ChildPath "01.12_start_up_apps.csv")
            )
            $Data = Get-CimInstance -ClassName Win32_StartupCommand | Select-Object -Property * | Sort-Object Caption
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
            Write-OutputToFile -Data $Data -OutputFile $TxtFile

            $RunKeys = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"
            )

            foreach($Key in $RunKeys) {
                "`n`nFrom : $Key`n" | Out-File -FilePath $TxtFile -Append -Encoding UTF8
                $KeyData = Invoke-RegistryCommand -Command { Get-ItemProperty $Key | Select-Object * -ExcludeProperty PS* }
                if ($KeyData) {
                    $KeyData | Out-File -FilePath $TxtFile -Append -Encoding UTF8
                }
                else {
                    $Msg = "No data found for registry key [ $( $Key ) ]"
                    $Msg | Out-File -FilePath $TxtFile -Append -Encoding UTF8
                }
            }
        }

        function Get-MotherboardInfo {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "01.13_motherboard.txt")
            )
            $Data = & Get-CimInstance -ClassName Win32_BaseBoard | Select-Object -Property *
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-DiskInfo {
        <#
        .SYNOPSIS
            Gets a list of all connected volumes that have a drive letter assigned and then runs the
            `Get-Disk` command on each of the drives and saves the output to a .CSV file.
        .PARAMETER CsvFile
            Path of the file to which the output of this function will be saved.
        #>
            [CmdletBinding()]
            param(
                [string]$CsvFile = (Join-Path -Path $DeviceFolder -ChildPath "01.14_disk_info.csv")
            )
            # All volumes that have a drive letter assigned
            $DriveLetters = Get-Volume |
                Where-Object { $_.DriveLetter } |
                Select-Object -ExpandProperty DriveLetter |
                Sort-Object

            # Properties that are just CIM plumbing and clutter the CSV
            $Skip = "CimClass", "CimInstanceProperties", "CimSystemProperties"

            $Rows = foreach ($Letter in $DriveLetters) {
                $Row = [ordered]@{ DriveLetter = $Letter }

                try {
                    $Disk = Get-Partition -DriveLetter $Letter -ErrorAction Stop |
                        Get-Disk -ErrorAction Stop

                    foreach ($Prop in $disk.PSObject.Properties) {
                        if ($Prop.Name -in $Skip) {
                            continue
                        }

                        $Value = $Prop.Value
                        # Flatten array values (e.g. OperationalStatus) so they're readable in a cell
                        if ($Value -is [array]) {
                            $Value = $Value -join "; "
                        }
                        $Row[$Prop.Name] = $Value
                    }
                }
                catch {
                    $Row["Error"] = $_.Exception.Message
                }

                [pscustomobject]$Row
            }

            if (-not $Rows) {
                Write-Warning "No drive letters found."
                return
            }

            # Export-Csv builds its columns from the first object, so make every row
            # share the same full set of columns (important if some drives errored)
            $AllProps = $Rows | ForEach-Object { $_.PSObject.Properties.Name } | Select-Object -Unique

            $Rows | Select-Object -Property $allProps |
                Export-Csv -Path $CsvFile -NoTypeInformation -Encoding UTF8
        }
    }

    process {
        # ----------------------------------
        # Run the functions from the module
        # ----------------------------------
        $Tasks = @(
            @{
                Action  = { Get-MiscDeviceData }
                Message = "01.01_Gathering Overall Device Information..."
                Files   = "01.01_device_info.txt"
            }
            @{
                Action  = { Get-SystemProcesses }
                Message = "01.02_Running SysInternals PSInfo.exe..."
                Files   = "01.02_PS_info.txt"
            }
            # @{
            #     Action  = { Get-FullFileList }
            #     Message = "01.03_Getting list of all files on the $env:SystemDrive\ path..."
            #     Files   = "01.03_full_dir_list.csv"
            # }
            @{
                Action  = { Get-CurrentComputerInfo }
                Message = "01.04_Parsing Computer Information..."
                Files   = "01.04_computer_info.txt"
            }
            @{
                Action  = { Get-SystemInfo1 }
                Message = "01.05_Parsing System Information (first)..."
                Files   = "01.05_system_info1.txt"
            }
            @{
                Action  = { Get-SystemInfo2 }
                Message = "01.06_Parsing System Information (second)..."
                Files   = "01.06_system_info2.txt"
            }
            @{
                Action  = { Get-PhysicalMemory }
                Message = "01.07_Getting Physical Memory Information..."
                Files   = "01.07_physical_memory.txt"
            }
            @{
                Action  = { Get-EnvVars }
                Message = "01.08_Getting Environment Variables..."
                Files   = "01.08_env_vars.txt"
            }
            @{
                Action  = { Get-DiskPart }
                Message = "01.09_Getting Disk Partition Information..."
                Files   = "01.09_disk_partitions.csv"
            }
            @{
                Action  = { Get-UserAccounts }
                Message = "01.10_Getting User Accounts & Current Login Information..."
                Files   = "01.10_user_accounts.csv"
            }
            @{
                Action  = { Get-LogonSessions }
                Message = "01.11_Getting Logon Sessions..."
                Files   = "01.11_logon_sessions.txt"
            }
            @{
                Action  = { Get-StartUpApps }
                Message = "01.12_Parsing Startup Apps from various sources..."
                Files   = "01.12_start_up_apps.txt", "01.12_start_up_apps.csv"
            }
            @{
                Action  = { Get-MotherboardInfo }
                Message = "01.13_Gathering Motherboard properties..."
                Files   = "01.13_motherboard.txt"
            }
            @{
                Action  = { Get-DiskInfo }
                Message = "01.14_Gathering Disk Information..."
                Files   = "01.14_disk_info.csv"
            }
        )
        Invoke-TriageTaskList -Tasks $Tasks -Folder $DeviceFolder
    }
}
