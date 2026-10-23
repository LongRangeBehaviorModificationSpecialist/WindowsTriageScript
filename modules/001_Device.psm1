function Get-TriageDeviceData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DeviceFolder
    )
    begin {
        function Get-MiscDeviceData {
            param (
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "device_info.txt")
            )
            $Data = Get-ComputerDetails
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-SystemProcesses {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "PS_info.txt")
            )

            & (Get-TriageBinary "PSInfo") -accepteula -s -h -d > $TxtFile 2>&1

            $Msg = "`n`nPsInfo was run with `-accepteula`, which creates `HKCU\Software\Sysinternals\PsInfo\EulaAccepted (DWORD = 1)` in the `NTUSER.DAT` of the account used to run the tool (<DOMAIN\user>). This change was made by the examiner's tool, not by the subject. In the current execution order, the snapshot of that account's registry hive is taken before PsInfo runs, so the collected copy will not contain the value."

            Add-Content -Path $TxtFile -Value $Msg -Encoding UTF8
        }

        function Get-FullFileList {
            param(
                [string]$CsvFile = (Join-Path -Path $DeviceFolder -ChildPath "full_dir_list.csv")
            )
            Get-ChildItem -LiteralPath "$env:SystemDrive\" -Recurse -Force -ErrorAction SilentlyContinue |
                Select-Object FullName, Length, Attributes, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc |
                Export-Csv -LiteralPath $CsvFile -NoTypeInformation -Encoding UTF8
        }

        function Get-CurrentComputerInfo {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "computer_info.txt")
            )
            $Data = Get-ComputerInfo
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-SystemInfo1 {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "system_info1.txt")
            )
            $Data = & (Get-TriageBinary "systeminfo") /FO LIST
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-SystemInfo2 {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "system_info2.txt")
            )
            $Data = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -Property *
            Write-OutputToFile -Data $Data -OutputFile $TxtFile -Append
        }

        function Get-PhysicalMemory {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "physical_memory.txt")
            )
            $Data = Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object -Property *
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-EnvVars {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "env_vars.txt")
            )
            $Data = Get-ChildItem -LiteralPath env: | Format-List
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-DiskPart {
            param(
                [string]$CsvFile = (Join-Path -Path $DeviceFolder -ChildPath "disk_partitions.csv")
            )
            $Data = Get-CimInstance -ClassName Win32_DiskPartition | Select-Object -Property * | Sort-Object -Property Name
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-UserAccounts {
            param(
                [string]$CsvFile = (Join-Path -Path $DeviceFolder -ChildPath "user_accounts.csv")
            )
            $Data = Get-CimInstance -ClassName Win32_UserProfile | Select-Object *, @{ N = "last used"; E = { $_.lastusetime } }
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-LogonSessions {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "logon_sessions.txt")
            )
            $Data = Get-CimInstance -ClassName Win32_LogonSession | Select-Object -Property *
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-StartUpApps {
            param(
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "start_up_apps.txt"),
                [string]$CsvFile = (Join-Path -Path $DeviceFolder -ChildPath "start_up_apps.csv")
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
                [string]$TxtFile = (Join-Path -Path $DeviceFolder -ChildPath "motherboard.txt")
            )
            $Data = & Get-CimInstance -ClassName Win32_BaseBoard | Select-Object -Property *
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }
    }
    process {
        # ----------------------------------
        # Run the functions from the module
        # ----------------------------------
        $Tasks = @(
            @{
                Action  = { Get-MiscDeviceData }
                Message = "Gathering Overall Device Information..."
                Files   = "device_info.txt"
            }
            @{
                Action  = { Get-SystemProcesses }
                Message = "Running SysInternals PSInfo.exe..."
                Files   = "PS_info.txt"
            }
            # @{
            #     Action  = { Get-FullFileList }
            #     Message = "Getting list of all files on the $env:SystemDrive\ path..."
            #     Files   = "full_dir_list.csv"
            # }
            @{
                Action  = { Get-CurrentComputerInfo }
                Message = "Parsing Computer Information..."
                Files   = "computer_info.txt"
            }
            @{
                Action  = { Get-SystemInfo1 }
                Message = "Parsing System Information (first)..."
                Files   = "system_info1.txt"
            }
            @{
                Action  = { Get-SystemInfo2 }
                Message = "Parsing System Information (second)..."
                Files   = "system_info2.txt"
            }
            @{
                Action  = { Get-PhysicalMemory }
                Message = "Getting Physical Memory Information..."
                Files   = "physical_memory.txt"
            }
            @{
                Action  = { Get-EnvVars }
                Message = "Getting Environment Variables..."
                Files   = "env_vars.txt"
            }
            @{
                Action  = { Get-DiskPart }
                Message = "Getting Disk Partition Information..."
                Files   = "disk_partitions.csv"
            }
            @{
                Action  = { Get-UserAccounts }
                Message = "Getting User Accounts & Current Login Information..."
                Files   = "user_accounts.csv"
            }
            @{
                Action  = { Get-LogonSessions }
                Message = "Getting Logon Sessions..."
                Files   = "logon_sessions.txt"
            }
            @{
                Action  = { Get-StartUpApps }
                Message = "Parsing Startup Apps from various sources..."
                Files   = "start_up_apps.txt", "start_up_apps.csv"
            }
            @{
                Action  = { Get-MotherboardInfo }
                Message = "Gathering Motherboard properties..."
                Files   = "motherboard.txt"
            }
        )
        Invoke-TriageTaskList -Tasks $Tasks -Folder $DeviceFolder
    }
}
