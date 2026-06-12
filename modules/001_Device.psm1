function Get-TriageDeviceData {
    [CmdletBinding()]
    param(
        [string]$deviceFolder
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


    function Get-MiscDeviceData {
        param(
            [string]$outputFile = "$deviceFolder\device_info.txt"
        )
        $command = { Get-ComputerDetails }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-SystemProcesses {
        param(
            [string]$outputFile = "$deviceFolder\PS_info.txt"
        )
        & $binaries["PSInfo"] -accepteula -s -h -d > $outputFile 2>&1
    }


    function Get-FullFileList {
        param(
            [string]$outputFile = "$deviceFolder\full_dir_list.txt"
        )
        $command = { cmd.exe /c "dir C:\ /A:H /Q /R /S /X" }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-CurrentComputerInfo {
        param(
            [string]$outputFile = "$deviceFolder\computer_info.txt"
        )
        $command = { Get-ComputerInfo }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-SystemInfo {
        param(
            [string]$outputFile = "$deviceFolder\system_info.txt"
        )
        $command1 = { systeminfo /FO LIST }
        $data1 = &($command1)
        Write-OutputToFile -Command $command1 -Data $data1 -OutputFile $outputFile

        $command2 = { Get-CimInstance -Class Win32_ComputerSystem | Select-Object -Property * }
        $data2 = &($command2)
        Write-OutputToFile -Command $command2 -Data $data2 -OutputFile $outputFile -Append
    }


    function Get-PhysicalMemory {
        param(
            [string]$outputFile = "$deviceFolder\physical_memory.txt"
        )
        $command = { Get-CimInstance -Class Win32_PhysicalMemory | Select-Object -Property * }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-EnvVars {
        param(
            [string]$outputFile = "$deviceFolder\env_vars.txt"
        )
        $command = { Get-ChildItem -Path env: | Format-List }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-DiskPart {
        param(
            [string]$outputFile = "$deviceFolder\disk_partitions.txt"
        )
        $command = { Get-CimInstance -ClassName Win32_DiskPartition | Format-List }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-UserAccounts {
        param(
            [string]$outputFile = "$deviceFolder\user_accounts.txt"
        )
        $command = { Get-CimInstance -ClassName Win32_UserProfile | Select-Object LocalPath, SID, @{ N = "last used"; E = { $_.ConvertToDateTime($_.lastusetime) } } | Out-File -FilePath $outputFile }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-LogonSessions {
        param(
            [string]$outputFile = "$deviceFolder\logon_sessions.txt"
        )
        $command = { Get-CimInstance -Class Win32_LogonSession | Select-Object -Property * }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-StartUpApps {
        param(
            [string]$outputFile = "$deviceFolder\start_up_apps.txt",
            [string]$csvOutputFile = "$deviceFolder\start_up_apps.csv"
        )
        $command = { Get-CimInstance -ClassName Win32_StartupCommand | Select-Object -Property * }
        $data = &($command)
        Save-OutputAsCsv -Data $data -OutputFile $csvOutputFile
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile

        "From : HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`n" | Out-File -FilePath $outputFile -Append
        Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" | Select-Object * -ExcludeProperty PS* | Out-File -FilePath $outputFile -Append

        "From : HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run`n" | Out-File -FilePath $outputFile -Append
        Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run" | Select-Object * -ExcludeProperty PS* | Out-File -FilePath $outputFile -Append

        "From : HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce`n" | Out-File -FilePath $outputFile -Append
        Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce" | Select-Object * -ExcludeProperty PS* | Out-File -FilePath $outputFile -Append

        "From : HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`n" | Out-File -FilePath $outputFile -Append
        Get-ItemProperty "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" | Select-Object * -ExcludeProperty PS* | Out-File -FilePath $outputFile -Append

        "From : HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run`n" | Out-File -FilePath $outputFile -Append
        Get-ItemProperty "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run" | Select-Object * -ExcludeProperty PS* | Out-File -FilePath $outputFile -Append

        "From : HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce`n" | Out-File -FilePath $outputFile -Append
        Get-ItemProperty "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce" | Select-Object * -ExcludeProperty PS* | Out-File -FilePath $outputFile -Append
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $workFlow = [ordered]@{
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
    }

    foreach ($task in $workFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
