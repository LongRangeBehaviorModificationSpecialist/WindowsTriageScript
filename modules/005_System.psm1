function Get-TriageSystemData {
    [CmdletBinding()]
    param(
        [string]$SystemFolder
    )


    $ConnectedDevicesFolder = Join-Path -Path $SystemFolder -ChildPath "Connected_Devices"
    $null = New-Item -ItemType Directory -Path $ConnectedDevicesFolder -Force


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$Action,
            [string]$FunctionMsg,
            [string]$OutputFile
        )
        try {
            Show-MessageAndWriteLogEntry -Msg $FunctionMsg -Level INFO
            & $Action
            Show-MessageAndWriteLogEntry -File $OutputFile -Level SUCCESS
        }
        catch {
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error: $( $_.Exception.Message )"
            Show-MessageAndWriteLogEntry -Msg $ErrorMsg -Level ERROR
        }
    }


    function Get-Last50Dlls {
        param(
            [string]$OutputFile = "$SystemFolder\last_50_dll_files.txt"
        )
        try {
            # Set up the .NET directory enumeration rules
            $Options = [System.IO.EnumerationOptions]::new()
            $Options.RecurseSubdirectories = $true
            $Options.AttributesToSkip = [System.IO.FileAttributes]::None
            $Options.IgnoreInaccessible = $true
            $Command =  { [System.IO.Directory]::EnumerateFiles("C:\", "*.dll", $Options) |
                            Get-Item |
                            Select-Object -Property Name, CreationTime, LastAccessTime, Directory |
                            Sort-Object -Property CreationTime -Descending |
                            Select-Object -First 50
                        }
            $Data = &($Command)
            Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
        }
        catch [System.IO.IOException] {
            $ErrorMsg = "Caught an IO Exception while running '$( $MyInvocation.MyCommand.Name )'. Error: $( $_.Exception.Message )"
            Show-MessageAndWriteLogEntry -Msg $ErrorMsg -Level ERROR
        }
    }


    function Get-OpenFilesList {
        param(
            [string]$OutputFile = "$SystemFolder\list_of_open_files.txt"
        )
        $Command = { openfiles /query }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-OpenShares {
        param(
            [string]$OutputFile = "$SystemFolder\open_shares.txt"
        )
        $Command =  { Get-CimInstance -ClassName Win32_Share |
                        Select-Object -Property * |
                        Sort-Object -Property Path
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-LogicalDisks {
        param(
            [string]$CsvOutputFile = "$SystemFolder\logical_disks.csv"
        )
        $Command =  { Get-CimInstance -ClassName Win32_LogicalDisk |
                        Select-Object -Property *
                    }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $CsvOutputFile
    }


    function Get-MappedLogicalDisks {
        param(
            [string]$OutputFile = "$SystemFolder\logical_disks_mapped.txt"
        )
        $Command =  { Get-CimInstance -ClassName Win32_MappedLogicalDisk |
                        Select-Object -Property * |
                        Format-List
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $CsvOutputFile
    }


    function Get-ScheduledJobs {
        param(
            [string]$OutputFile = "$SystemFolder\scheduled_jobs.txt"
        )
        $Command =  { Get-CimInstance -ClassName Win32_ScheduledJob }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-ScheduledTasks {
        param(
            [string]$OutputFile     = "$SystemFolder\scheduled_task_events.txt",
            [string]$InfoOutputFile = "$SystemFolder\scheduled_task_info.txt"
        )
        $Command1 = { Get-ScheduledTask |
                        Select-Object -Property * |
                        Where-Object { $_.State -ne "Disabled" } |
                        Format-List
                    }
        $Command2 = { Get-ScheduledTask |
                        Where-Object { $_.State -ne "Disabled" } |
                        Get-ScheduledTaskInfo
                    }
        $Data1 = &$Command1
        $Data2 = &$Command2
        Write-OutputToFile -Command $Command1 -Data $Data1 -OutputFile $OutputFile
        Write-OutputToFile -Command $Command2 -Data $Data2 -OutputFile $InfoOutputFile
    }


    function Get-HotFixes {
        param(
            [string]$OutputFile = "$SystemFolder\hot_fixes.csv"
        )
        $Command =  { Get-HotFix |
                        Select-Object -Property *
                    }
        $Data = &($Command)
        Write-OutputToCsv -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-InstalledApps {
        param(
            [string]$InstalledAppsFile       = "C:\Users\mikes\Desktop\query\installedApps_list.csv",
            [string]$InstalledAppsProps      = "C:\Users\mikes\Desktop\query\installedAppsProps.csv",
            [string]$InstalledAppsWow64      = "C:\Users\mikes\Desktop\query\installedApps_list_wow64.csv",
            [string]$InstalledAppsWow64Props = "C:\Users\mikes\Desktop\query\installedAppsProps_wow64.csv"
        )

        $Props = [ordered]@{
            "a" = ( { Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select-Object -Property * | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $InstalledAppsFile }, $InstalledAppsFile)
            "b" = ( { Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select-Object -Property * | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $InstalledAppsProps }, $InstalledAppsProps)
            "c" = ( { Get-ChildItem "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select-Object -Property * | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $InstalledAppsWow64 }, $InstalledAppsWow64)
            "d" = ( { Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select-Object -Property * | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $InstalledAppsWow64Props }, $InstalledAppsWow64Props)
        }
        foreach ($X in $Props.GetEnumerator()) {
            $Command = $X.value[0]
            $Data = &($Command)
        }
    }


    function Get-VolumeShadowCopies {
        param(
            [string]$OutputFile = "$SystemFolder\volume_shadow_copies.csv"
        )
        $Command =  { Get-CimInstance -ClassName Win32_ShadowCopy |
                        Select-Object -Property *
                    }
        $Data = &($Command)
        Write-OutputAsCsv -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-AppInitDllKey {
        param(
            [string]$OutputFile = "$SystemFolder\appinit_dll_key.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" |
                        Select-Object AppInit_DLLs
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-UacGroupPolicy {
        param(
            [string]$OutputFile = "$SystemFolder\uac_group_policy.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" |
                        Select-Object * -ExcludeProperty PS*
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-ActiveSetupInstalls {
        param(
            [string]$OutputFile = "$SystemFolder\active_setup_installs.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\*" |
                        Select-Object ComponentID, Version, "(Default)", StubPath |
                        Format-List
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-AppPathRegKeys {
        param(
            [string]$OutputFile = "$SystemFolder\app_path_reg_keys.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\*" |
                        Select-Object PSChildName, "(Default)" |
                        Format-List
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-DllsLoadedByExplorerShell {
        param(
            [string]$OutputFile = "$SystemFolder\dlls_loaded_by_explorer_shell.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\*\*" |
                        Select-Object "(Default)", DllName
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-ShellAndUserInitValues {
        param(
            [string]$OutputFile = "$SystemFolder\shell_and_user_init_values.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" |
                        Select-Object * -ExcludeProperty PS*
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-SvcValues {
        param(
            [string]$OutputFile = "$SystemFolder\svc_values.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Security Center\Svc" |
                        Select-Object * -ExcludeProperty PS*
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-DesktopAddressBar {
        param(
            [string]$OutputFile = "$SystemFolder\desktop_address_bar.txt"
        )
        $Command =  { Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths" |
                        Select-Object * -ExcludeProperty PS*
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-RunMruKeyInfo {
        param(
            [string]$OutputFile = "$SystemFolder\run_mru_key_info.txt"
        )
        $Command =  { Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" |
                        Select-Object * -ExcludeProperty PS*
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-StartMenuData {
        param(
            [string]$OutputFile = "$SystemFolder\start_menu_data.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartMenu" |
                        Select-Object * -ExcludeProperty PS* |
                        Format-List
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-ProgExeBySessionManager {
        param(
            [string]$OutputFile = "$SystemFolder\prog_exe_by_session_manager.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" |
                        Select-Object * -ExcludeProperty PS*
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-ShellFolderInfo {
        param(
            [string]$OutputFile = "$SystemFolder\shell_foldes.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-ApprovedShellExts {
        param(
            [string]$OutputFile = "$SystemFolder\approved_shell_exts.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-AppCertDlls {
        param(
            [string]$OutputFile = "$SystemFolder\app_cert_dlls.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCertDlls" }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-ExeFileShellCommands {
        param(
            [string]$OutputFile = "$SystemFolder\exe_file_shell_commands.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SOFTWARE\Classes\exefile\shell\open\command" }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-ShellCommands {
        param(
            [string]$OutputFile = "$SystemFolder\shell_commands.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SOFTWARE\Classes\http\shell\open\command" |
                        Select-Object "(Default)"
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-BcdRelatedData {
        param(
            [string]$OutputFile = "$SystemFolder\bcd_related_data.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\BCD00000000\*\*\*\*" |
                        Select-Object Element |
                        Select-String "exe" |
                        Select-Object Line
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-LoadedLsaPackages {
        param(
            [string]$OutputFile = "$SystemFolder\loaded_lsa_packages.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" |
                        Select-Object -Property *
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-BrowserHelperObjects {
        param(
            [string]$OutputFile = "$SystemFolder\browser_helper_objects.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\*" |
                        Select-Object "(Default)"
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-BrowserHelperObjectsX64 {
        param(
            [string]$OutputFile = "$SystemFolder\browser_helper_objects_x64.txt"
        )
        $Command =  { Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\*" |
                        Select-Object "(Default)"
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-IeExtensions {
        param(
            [string]$OutputFile = "$SystemFolder\ie_extensions.txt"
        )
        Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Internet Explorer\Extensions\*" | Select-Object ButtonText, Icon | Out-File -FilePath $OutputFile
        Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Extensions\*" | Select-Object ButtonText, Icon | Out-File -Append -FilePath $OutputFile
        Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Extensions\*" | Select-Object ButtonText, Icon | Out-File -Append -FilePath $OutputFile
    }


    function Get-UsbDevices {
        param(
            [string]$OutputFile = "$ConnectedDevicesFolder\usb_devices.csv"
        )
        $Command =  { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\*\*" |
                        Select-Object -Property *
                    }
        $Data = &($Command)
        Write-OutputToCsv -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-PnpDevices {
        param(
            [string]$OutputFile = "$ConnectedDevicesFolder\pnp_devices.csv"
        )
        $Command =  { Get-PnpDevice | Select-Object -Property *}
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    function Copy-HostFile {
        param(
            [string]$OutputFile = "$SystemFolder\hosts_file.txt"
        )
        $Command = { Get-Content $Env:windir\system32\drivers\etc\hosts }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Copy-ServicesFile {
        param(
            [string]$OutputFile = "$SystemFolder\services_file.txt"
        )
        $Command =  { Get-Content $Env:windir\system32\drivers\etc\services }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-AuditPolicy {
        param(
            [string]$OutputFile = "$SystemFolder\audit_policy.txt"
        )
        $Command =  { auditpol /get /category:* }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-NonValidExes {
        param(
            [string]$OutputFile = "$SystemFolder\non_valid_exe_files.txt"
        )
        $Command =  { Get-ChildItem -Force -Recurse -Path "C:\Windows\*\*.exe" -File |
                        Get-AuthenticodeSignature |
                        Where-Object { $_.status -ne "Valid" }
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-WindowsUpdateEtlFiles {
        param(
            [string]$OutputFile = "$SystemFolder\windows_update_log.txt"
        )
        $Command = { Get-WindowsUpdateLog -IncludeAllLogs }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-WindowsFeaturesList {
        param(
            [string]$OutputFile = "$SystemFolder\windows_features_list.txt"
        )
        $Command = { dism /online /get-features }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-WindowsCapabilitiesList {
        param(
            [string]$OutputFile = "$SystemFolder\windows_capabilities_list.txt"
        )
        $Command = { dism /online /get-capabilities }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $SystemWorkFlow = [ordered]@{
        # { Get-Last50Dlls } = (
        #     "Getting Last 50 Created .dll Files...",
        #     "last_50_dll_files.txt"
        # )
        { Get-OpenFilesList } = (
            "Processing List of Open Files...",
            "list_of_open_files.txt"
        )
        { Get-OpenShares } = (
            "Getting Open Shares...",
            "open_shares.txt"
        )
        { Get-LogicalDisks } = (
            "Getting Logical Drives...",
            "logical_disks.csv"
        )
        { Get-MappedLogicalDisks } = (
            "Getting Mapped Logical Disks...",
            "logical_disk_mapped.txt"
        )
        { Get-ScheduledJobs } = (
            "Listing Scheduled Jobs...",
            "scheduled_jobs.txt"
        )
        { Get-ScheduledTasks } = (
            "Getting Scheduled Tasks and Task Info...",
            "[scheduled_task_events.txt, scheduled_task_events.csv]"
        )
        { Get-HotFixes } = (
            "Listing Applied HotFixes...",
            "hot_fixes.txt"
        )
        { Get-InstalledApps } = (
            "Getting Installed Applications (Default & Wow6432Node)...",
            "[installedApps_list.csv, installedAppsProps.csv, installedApps_list_wow64.csv, installedAppsProps_wow64.csv]"
        )
        { Get-VolumeShadowCopies } = (
            "Listing Volume Shadow Copies...",
            "volume_shadow_copies.txt"
        )
        { Get-AppInitDllKey } = (
            "Getting AppInit_DLL Registry Keys...",
            "appinit_dll_key.txt"
        )
        { Get-UacGroupPolicy } = (
            "Listing UAC Group Policy Settings...",
            "uac_group_policy.txt"
        )
        { Get-ActiveSetupInstalls } = (
            "Getting Active Setup Installs...",
            "active_setup_installs.txt"
        )
        { Get-AppPathRegKeys } = (
            "Getting App Path Registry Keys...",
            "app_path_reg_keys.txt"
        )
        { Get-DllsLoadedByExplorerShell } = (
            "Listing .dll Files Loaded by Explorer.exe Shell...",
            "dlls_loaded_by_explorer_shell.txt"
        )
        { Get-ShellAndUserInitValues } = (
            "Getting Shell and UserInit Values...",
            "shell_and_user_init_values.txt"
        )
        { Get-SvcValues } = (
            "Listing Security Center SVC Values...",
            "svc_values.txt"
        )
        { Get-DesktopAddressBar } = (
            "Parsing Desktop Address Bar History...",
            "desktop_address_bar.txt"
        )
        { Get-RunMruKeyInfo } = (
            "Getting RunMRU key Information...",
            "run_mru_key_info.txt"
        )
        { Get-StartMenuData } = (
            "Listing Start Menu Data...",
            "start_menu_data.txt"
        )
        { Get-ProgExeBySessionManager } = (
            "Listing Programs Executed by Session Manager...",
            "prog_exe_by_session_manager.txt"
        )
        { Get-ShellFolderInfo } = (
            "Getting User Startup Shell Folder Information...",
            "shellFolders.txt"
        )
        { Get-ApprovedShellExts } = (
            "Listing Approved Shell Extensions...",
            "approved_shell_exts.txt"
        )
        { Get-AppCertDlls } = (
            "Listing AppCert .dll Files...",
            "app_cert_dlls.txt"
        )
        { Get-ExeFileShellCommands } = (
            "Listing .exe File Shell Command Configuration...",
            "exe_file_shell_commands.txt"
        )
        { Get-ShellCommands } = (
            "Listing Shell Commands...",
            "shell_commands.txt"
        )
        { Get-BcdRelatedData } = (
            "Getting BCD Related Data...",
            "bcd_related_data.txt"
        )
        { Get-LoadedLsaPackages } = (
            "Reading Loaded LSA Packages Data...",
            "loaded_lsa_packages.txt"
        )
        { Get-BrowserHelperObjects } = (
            "Parsing Browser Helper Objects...",
            "browser_helper_objects.txt"
        )
        { Get-BrowserHelperObjectsX64 } = (
            "Parsing Browser Helper Objects (64 Bit)...",
            "browser_helper_objects_x64.txt"
        )
        { Get-IeExtensions } = (
            "Parsing Internet Explorer Extensions Data...",
            "ie_extensions.txt"
        )
        { Get-UsbDevices } = (
            "Listing Connected USB Devices...",
            "usb_devices.txt"
        )
        { Get-PnpDevices } = (
            "Listing Connected PnP Devices...",
            "pnp_devices.csv"
        )
        { Copy-HostFile } = (
            "Copying *hosts* File...",
            "hosts_file.txt"
        )
        { Copy-ServicesFile } = (
            "Copying *services* File...",
            "services_file.txt"
        )
        { Get-AuditPolicy } = (
            "Listing Computer Audit Policy...",
            "audit_policy.txt"
        )
        { Get-NonValidExes } = (
            "Listing Executables Without Valid Authenticode Signature...",
            "non_valid_exe_files.txt"
        )
        { Get-WindowsUpdateEtlFiles } = (
            "Gathering Windows Update logs...",
            "windows_update_log.txt"
        )
        { Get-WindowsFeaturesList } = (
            "Gathering List of Windows Features...",
            "windows_features_list.txt"
        )
        { Get-WindowsCapabilitiesList }   = (
            "Gathering List of Windows Capabilities...",
            "windows_capabilities_list.txt"
        )
    }

    foreach ($Task in $SystemWorkFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $Task.key -functionMsg $Task.value[0] -OutputFile $Task.value[1]
    }
}
