function Get-TriageDeviceData {
    [CmdletBinding()]
    param ([string]$DeviceFolder)

    function Invoke-ScriptBlock {
        param (
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

    function Get-MiscDeviceData {
        param ([string]$OutputFile = "$DeviceFolder\device_info.txt")
        $Command =  { Get-ComputerDetails }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-SystemProcesses {
        param([string]$OutputFile = "$DeviceFolder\PS_info.txt")
        # & (Get-TriageBinary -Name "PSInfo") -accepteula -s -h -d > $OutputFile 2>&1
        & $global:Binaries["PSInfo"] -accepteula -s -h -d > $OutputFile 2>&1
    }

    function Get-FullFileList {
        param([string]$OutputFile = "$DeviceFolder\full_dir_list.csv")
        # $Command =  { cmd.exe /c "dir C:\ /A:H /Q /R /S /X" }
        $Command = { Get-ChildItem -Path $env:SystemDrive\ -Recurse -Force -ErrorAction SilentlyContinue | Select-Object FullName, Length, Attributes, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc }
        $Data = &($Command)
        Write-OutputToCsv -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-CurrentComputerInfo {
        param([string]$OutputFile = "$DeviceFolder\computer_info.txt")
        $Command =  { Get-ComputerInfo }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-SystemInfo {
        param([string]$OutputFile = "$DeviceFolder\system_info.txt")
        $Command1 = { systeminfo /FO LIST }
        $Data1 = &($Command1)
        Write-OutputToFile -Command $Command1 -Data $Data1 -OutputFile $OutputFile

        $Command2 = { Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -Property * }
        $Data2 = &($Command2)
        Write-OutputToFile -Command $Command2 -Data $Data2 -OutputFile $OutputFile -Append
    }

    function Get-PhysicalMemory {
        param([string]$OutputFile = "$DeviceFolder\physical_memory.txt")
        $Command = { Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-EnvVars {
        param([string]$OutputFile = "$DeviceFolder\env_vars.txt")
        $Command = { Get-ChildItem -Path env: | Format-List }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-DiskPart {
        param([string]$OutputFile = "$DeviceFolder\disk_partitions.csv")
        $Command = { Get-CimInstance -ClassName Win32_DiskPartition | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-UserAccounts {
        param([string]$OutputFile = "$DeviceFolder\user_accounts.txt")
        $Command = { Get-CimInstance -ClassName Win32_UserProfile | Select-Object LocalPath, SID, @{ N = "last used"; E = { $_.lastusetime } } }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-LogonSessions {
        param([string]$OutputFile = "$DeviceFolder\logon_sessions.txt")
        $Command = { Get-CimInstance -ClassName Win32_LogonSession | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-StartUpApps {
        param(
            [string]$OutputFile    = "$DeviceFolder\start_up_apps.txt",
            [string]$CsvOutputFile = "$DeviceFolder\start_up_apps.csv"
        )
        $Command = { Get-CimInstance -ClassName Win32_StartupCommand | Select-Object -Property * | Sort-Object Caption }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $CsvOutputFile
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile

        $RunKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run'
        )

        foreach($Key in $RunKeys) {
            "From : $Key`n" | Out-File -FilePath $OutputFile -Append -Encoding utf8
            $KeyData = Invoke-RegistryCommand -Command { Get-ItemProperty $Key | Select-Object * -ExcludeProperty PS* }
            if ($KeyData) {
                $KeyData | Out-File -FilePath $OutputFile -Append -Encoding utf8
            }
            else {
                "No data was found for that registry key.`n" | Out-File -FilePath $OutputFile -Append -Encoding utf8
            }
        }
    }

    function Get-MotherboardInfo {
        param([string]$OutputFile = "$DeviceFolder\motherboard.txt")
        $Command = { Get-CimInstance -ClassName Win32_BaseBoard | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $DeviceWorkFlow = [ordered]@{

        { Get-MiscDeviceData } = (
            "Gathering Overall Device Information...",
            "device_info.txt"
        )
        { Get-SystemProcesses } = (
            "Running SysInternals PSInfo.exe...",
            "PS_info.txt"
        )
        # { Get-FullFileList } = (
        #     "Getting list of all files on the $env:SystemDrive\ path...",
        #     "full_dir_list.csv"
        # )
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
            "[start_up_apps.txt, start_up_apps.csv, start_up_apps_per_user.csv]"
        )
        { Get-MotherboardInfo } = (
            "Gathering Motherboard properties...",
            "motherboard.txt"
        )
    }

    foreach ($Task in $DeviceWorkFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $Task.key -FunctionMessage $Task.value[0] -OutputFile $Task.value[1]
    }
}
