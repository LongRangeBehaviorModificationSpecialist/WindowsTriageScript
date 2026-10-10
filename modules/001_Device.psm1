function Get-TriageDeviceData {
    [CmdletBinding()]
    param(
        [string]$DeviceFolder
    )

    function Get-MiscDeviceData {
        param (
            [string]$TxtFile = Join-Path -Path $DeviceFolder -ChildPath "device_info.txt"
        )
        $Command =  { Get-ComputerDetails }
        $Data = &($Command)
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }

    function Get-SystemProcesses {
        param(
            [string]$TxtFile = "$DeviceFolder\PS_info.txt"
        )

        & (Get-TriageBinary "PSInfo") -accepteula -s -h -d > $TxtFile 2>&1

        $Msg = "`n`nPsInfo was run with `-accepteula`, which creates `HKCU\Software\Sysinternals\PsInfo\EulaAccepted (DWORD = 1)` in the `NTUSER.DAT` of the account used to run the tool (<DOMAIN\user>). This change was made by the examiner's tool, not by the subject. In the current execution order, the snapshot of that account's registry hive is taken before PsInfo runs, so the collected copy will not contain the value."

        Add-Content -Path $TxtFile -Value $Msg -Encoding UTF8
    }

    function Get-FullFileList {
        param(
            [string]$CsvFile = "$DeviceFolder\full_dir_list.csv"
        )
        Get-ChildItem -LiteralPath "$env:SystemDrive\" -Recurse -Force -ErrorAction SilentlyContinue | Select-Object FullName, Length, Attributes, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc | Export-Csv -LiteralPath $CsvFile -NoTypeInformation -Encoding UTF8
    }

    function Get-CurrentComputerInfo {
        param(
            [string]$TxtFile = "$DeviceFolder\computer_info.txt"
        )
        $Command =  { Get-ComputerInfo }
        $Data = &($Command)
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }

    function Get-SystemInfo {
        param(
            [string]$TxtFile = "$DeviceFolder\system_info.txt"
        )
        $Command1 = { & (Get-TriageBinary "systeminfo") /FO LIST }
        $Data1 = &($Command1)
        Write-OutputToFile -Data $Data1 -OutputFile $TxtFile

        $Command2 = { Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -Property * }
        $Data2 = &($Command2)
        Write-OutputToFile -Data $Data2 -OutputFile $TxtFile -Append
    }

    function Get-PhysicalMemory {
        param(
            [string]$TxtFile = "$DeviceFolder\physical_memory.txt"
        )
        $Command = { Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }

    function Get-EnvVars {
        param(
            [string]$TxtFile = "$DeviceFolder\env_vars.txt"
        )
        $Command = { Get-ChildItem -LiteralPath env: | Format-List }
        $Data = &($Command)
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }

    function Get-DiskPart {
        param(
            [string]$CsvFile = "$DeviceFolder\disk_partitions.csv"
        )
        $Command = { Get-CimInstance -ClassName Win32_DiskPartition | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile
    }

    function Get-UserAccounts {
        param(
            [string]$TxtFile = "$DeviceFolder\user_accounts.txt"
        )
        $Command = { Get-CimInstance -ClassName Win32_UserProfile | Select-Object LocalPath, SID, @{ N = "last used"; E = { $_.lastusetime } } }
        $Data = &($Command)
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }

    function Get-LogonSessions {
        param(
            [string]$TxtFile = "$DeviceFolder\logon_sessions.txt"
        )
        $Command = { Get-CimInstance -ClassName Win32_LogonSession | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }

    function Get-StartUpApps {
        param(
            [string]$TxtFile = "$DeviceFolder\start_up_apps.txt",
            [string]$CsvFile = "$DeviceFolder\start_up_apps.csv"
        )
        $Command = { Get-CimInstance -ClassName Win32_StartupCommand | Select-Object -Property * | Sort-Object Caption }
        $Data = &($Command)
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
            "`n`nFrom : $Key`n" | Out-File -FilePath $OutputFile -Append -Encoding UTF8
            $KeyData = Invoke-RegistryCommand -Command { Get-ItemProperty $Key | Select-Object * -ExcludeProperty PS* }
            if ($KeyData) {
                $KeyData | Out-File -FilePath $TxtFile -Append -Encoding UTF8
            }
            else {
                $Msg = "No data found for registry key [ $( $Key ) ]"
                $Key | Out-File -FilePath $TxtFile -Append -Encoding UTF8
            }
        }
    }

    function Get-MotherboardInfo {
        param(
            [string]$TxtFile = "$DeviceFolder\motherboard.txt"
        )
        $Command = { Get-CimInstance -ClassName Win32_BaseBoard | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }

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
            Action  = { Get-SystemInfo }
            Message = "Parsing System Information..."
            Files   = "system_info.txt"
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
            Files   = "user_accounts.txt"
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
