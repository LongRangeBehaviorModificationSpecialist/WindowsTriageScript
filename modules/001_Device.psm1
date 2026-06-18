function Get-TriageDeviceData {
    [CmdletBinding()]
    param(
        [string]$device_folder
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


    function Get-MiscDeviceData {
        param(
            [string]$output_file = "$device_folder\device_info.txt"
        )
        $command =  { Get-ComputerDetails }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-SystemProcesses {
        param(
            [string]$output_file = "$device_folder\PS_info.txt"
        )
        & $binaries["PSInfo"] -accepteula -s -h -d > $output_file 2>&1
    }


    function Get-FullFileList {
        param(
            [string]$output_file = "$device_folder\full_dir_list.txt"
        )
        $command =  { cmd.exe /c "dir C:\ /A:H /Q /R /S /X" }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-CurrentComputerInfo {
        param(
            [string]$output_file = "$device_folder\computer_info.txt"
        )
        $command =  { Get-ComputerInfo }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-SystemInfo {
        param(
            [string]$output_file = "$device_folder\system_info.txt"
        )
        $command1 = { systeminfo /FO LIST }
        $data1 = &($command1)
        Write-OutputToFile -Command $command1 -Data $data1 -OutputFile $output_file

        $command2 = { Get-CimInstance -ClassName Win32_ComputerSystem |
                        Select-Object -Property *
                    }
        $data2 = &($command2)
        Write-OutputToFile -Command $command2 -Data $data2 -OutputFile $output_file -Append
    }


    function Get-PhysicalMemory {
        param(
            [string]$output_file = "$device_folder\physical_memory.txt"
        )
        $command =  { Get-CimInstance -ClassName Win32_PhysicalMemory |
                        Select-Object -Property *
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-EnvVars {
        param(
            [string]$output_file = "$device_folder\env_vars.txt"
        )
        $command =  { Get-ChildItem -Path env: |
                        Format-List
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-DiskPart {
        param(
            [string]$output_file = "$device_folder\disk_partitions.csv"
        )
        $command =  { Get-CimInstance -ClassName Win32_DiskPartition |
                        Select-Object -Property *
                    }
        $data = &($command)
        Write-OutputToCsv -Command $command -Data $data -OutputFile $output_file
    }


    function Get-UserAccounts {
        param(
            [string]$output_file = "$device_folder\user_accounts.txt"
        )
        $command =  { Get-CimInstance -ClassName Win32_UserProfile |
                        Select-Object LocalPath, SID, @{ N = "last used"; E = { $_.lastusetime } }
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-LogonSessions {
        param(
            [string]$output_file = "$device_folder\logon_sessions.txt"
        )
        $command =  { Get-CimInstance -ClassName Win32_LogonSession |
                        Select-Object -Property *
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-StartUpApps {
        param(
        [string]$output_file     = "$device_folder\start_up_apps.txt",
        [string]$csv_output_file = "$device_folder\start_up_apps.csv"
        )
        $command =  { Get-CimInstance -ClassName Win32_StartupCommand |
                        Select-Object -Property * |
                        Sort-Object Caption
                    }
        $data = &($command)
        Write-OutputToCsv -Data $data -OutputFile $csv_output_file
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file

        "From : HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`n" | Out-File -FilePath $output_file -Append
        Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" | Select-Object * -ExcludeProperty PS* | Out-File -FilePath $output_file -Append

        "From : HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run`n" | Out-File -FilePath $output_file -Append
        Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run" | Select-Object * -ExcludeProperty PS* | Out-File -FilePath $output_file -Append

        "From : HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce`n" | Out-File -FilePath $output_file -Append
        Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce" | Select-Object * -ExcludeProperty PS* | Out-File -FilePath $output_file -Append

        "From : HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`n" | Out-File -FilePath $output_file -Append
        Get-ItemProperty "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" | Select-Object * -ExcludeProperty PS* | Out-File -FilePath $output_file -Append

        "From : HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run`n" | Out-File -FilePath $output_file -Append
        Get-ItemProperty "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run" | Select-Object * -ExcludeProperty PS* | Out-File -FilePath $output_file -Append

        "From : HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce`n" | Out-File -FilePath $output_file -Append
        Get-ItemProperty "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce" | Select-Object * -ExcludeProperty PS* | Out-File -FilePath $output_file -Append
    }


    function Get-MotherboardInfo {
        param(
            [string]$output_file = "$device_folder\motherboard.txt"
        )
        $command =  { Get-CimInstance -ClassName Win32_BaseBoard |
                        Select-Object -Property *
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $device_work_flow = [ordered]@{
        { Get-MiscDeviceData } = (
            "Gathering Overall Device Information...",
            "device_info.txt"
        )
        { Get-SystemProcesses } = (
            "Running SysInternals PSInfo.exe...",
            "PS_info.txt"
        )
        { Get-FullFileList } = (
            "Getting list of all files on the C:\ drive...",
            "full_dir_list.txt"
        )
        { Get-CurrentComputerInfo } = (
            "Parsing Computer Information...",
            "computer_info.txt"
        )
        { Get-SystemInfo } = (
            "Parsing System Information...",
            "system_info.txt"
        )
        { Get-PhysicalMemory } = (
            "Getting Physical Memory Information...",
            "physical_memory.txt"
        )
        { Get-EnvVars } = (
            "Getting Environment Variables...",
            "env_vars.txt"
            )
        { Get-DiskPart } = (
            "Getting Disk Partition Information...",
            "disk_partitions.txt"
        )
        { Get-UserAccounts } = (
            "Getting User Accounts & Current Login Information...",
            "user_accounts.txt"
        )
        { Get-LogonSessions } = (
            "Getting Logon Sessions...",
            "logon_sessions.txt"
        )
        { Get-StartUpApps } = (
            "Parsing Startup Apps from various sources...",
            "[start_up_apps.txt, start_up_apps.csv]"
        )
        { Get-MotherboardInfo } = (
            "Gathering Motherboard properties...",
            "motherboard.txt"
        )
    }

    foreach ($task in $device_work_flow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
