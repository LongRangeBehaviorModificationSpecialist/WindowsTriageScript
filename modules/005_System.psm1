function Get-TriageSystemData {
    [CmdletBinding()]
    param(
        [string]$systemFolder
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


    function Get-Last50Dlls {
        param(
            [string]$outputFile = "$systemFolder\last_50_dll_files.txt"
        )
        try {
            $command = { Get-ChildItem -Path C:\ -Recurse -Force -Include *.dll | Select-Object Name, CreationTime, LastAccessTime, Directory | Sort-Object CreationTime -Desc | Select-Object -first 50 }
            $data = &($command)
            Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
        }
        catch [System.IO.IOException] {
            $errorMessage = "Caught an IO Exception while running '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
            Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
        }
    }


    function Get-OpenFilesList {
        param(
            [string]$outputFile = "$systemFolder\list_of_open_files.txt"
        )
        $command = { openfiles /query }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-OpenShares {
        param(
            [string]$outputFile = "$systemFolder\open_shares.txt"
        )
        $command = { Get-CimInstance -ClassName Win32_Share | Select-Object Name, Path, Description }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-MappedDrives {
        param(
            [string]$outputFile = "$systemFolder\mapped_drives.txt"
        )
        $command = { Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Map Network Drive MRU" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-LogicalDisks {
        param(
            [string]$csvOutputFile = "$systemFolder\logical_disks.csv"
        )
        $command = { Get-WMIObject -Class Win32_LogicalDisk | Select-Object -Property * }
        $data = &($command)
        Save-OutputAsCsv -Data $data -OutputFile $csvOutputFile
    }


    function Get-MappedLogicalDisks {
        param(
            [string]$outputFile = "$systemFolder\logical_disks_mapped.txt"
        )
        $command = { Get-WMIObject -Class Win32_MappedLogicalDisk | Select-Object -Property * | Format-List }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $csvOutputFile
    }


    function Get-ScheduledJobs {
        param(
            [string]$outputFile = "$systemFolder\scheduled_jobs.txt"
        )
        $command = { Get-CIMinstance -ClassName Win32_ScheduledJob }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-ScheduledTasks {
        param(
            [string]$outputFile = "$systemFolder\scheduled_task_events.txt",
            [string]$InfoOutputFile = "$systemFolder\scheduled_task_info.txt"
        )
        $command1 = { Get-ScheduledTask | Where-Object { $_.State -ne "Disabled" } | Format-List }
        $command2 = { Get-ScheduledTask | Where-Object { $_.State -ne "Disabled" } | Get-ScheduledTaskInfo }
        $data1 = &$command1
        $data2 = &$command2
        Write-OutputToFile -Command $command1 -Data $data1 -OutputFile $outputFile
        Write-OutputToFile -Command $command2 -Data $data2 -OutputFile $InfoOutputFile
    }


    function Get-HotFixes {
        param(
            [string]$outputFile = "$systemFolder\hot_fixes.txt"
        )
        $command = { Get-HotFix | Select-Object HotfixID, Description, InstalledBy, InstalledOn | Sort-Object InstalledOn -Descending }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-InstalledApps {
        param(
            [string]$InstalledAppsFile = "C:\Users\mikes\Desktop\query\installed_apps_list.csv",
            [string]$InstalledAppsProps = "C:\Users\mikes\Desktop\query\installed_apps_props.csv",
            [string]$InstalledAppsWow64 = "C:\Users\mikes\Desktop\query\installed_apps_list_wow64.csv",
            [string]$InstalledAppsWow64Props = "C:\Users\mikes\Desktop\query\installed_apps_props_wow64.csv"
        )

        $Props = [ordered]@{
            "a" = ( { Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select-Object -Property * | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $InstalledAppsFile }, $InstalledAppsFile)
            "b" = ( { Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select-Object -Property * | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $InstalledAppsProps }, $InstalledAppsProps)
            "c" = ( { Get-ChildItem "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select-Object -Property * | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $InstalledAppsWow64 }, $InstalledAppsWow64)
            "d" = ( { Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select-Object -Property * | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $InstalledAppsWow64Props }, $InstalledAppsWow64Props)
        }
        foreach ($x in $Props.GetEnumerator()) {
            $command = $x.value[0]
            $data = &($command)
        }
    }


    function Get-VolumeShadowCopies {
        param(
            [string]$outputFile = "$systemFolder\volume_shadow_copies.txt"
        )
        $command = { Get-CimInstance -ClassName Win32_ShadowCopy | Select-Object DeviceObject, @{N = "CreationDate"; E = { $_.ConvertToDateTime($_.InstallDate) } } }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-AppInitDllKey {
        param(
            [string]$outputFile = "$systemFolder\appinit_dll_key.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" | Select-Object AppInit_DLLs }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-UacGroupPolicy {
        param(
            [string]$outputFile = "$systemFolder\uac_group_policy.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-ActiveSetupInstalls {
        param(
            [string]$outputFile = "$systemFolder\active_setup_installs.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\*" | Select-Object ComponentID, Version, "(Default)", StubPath | Format-List }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-AppPathRegKeys {
        param(
            [string]$outputFile = "$systemFolder\app_path_reg_keys.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\*" | Select-Object PSChildName, "(Default)" | Format-List }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-DllsLoadedByExplorerShell {
        param(
            [string]$outputFile = "$systemFolder\dlls_loaded_by_explorer_shell.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\*\*" | Select-Object "(Default)", DllName }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-ShellAndUserInitValues {
        param(
            [string]$outputFile = "$systemFolder\shell_and_user_init_values.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-SvcValues {
        param(
            [string]$outputFile = "$systemFolder\svc_values.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Security Center\Svc" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-DesktopAddressBar {
        param(
            [string]$outputFile = "$systemFolder\desktop_address_bar.txt"
        )
        $command = { Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-RunMruKeyInfo {
        param(
            [string]$outputFile = "$systemFolder\run_mru_key_info.txt"
        )
        $command = { Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-StartMenuData {
        param(
            [string]$outputFile = "$systemFolder\start_menu_data.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartMenu" | Select-Object * -ExcludeProperty PS* | Format-List }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-ProgExeBySessionManager {
        param(
            [string]$outputFile = "$systemFolder\prog_exe_by_session_manager.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-ShellFolderInfo {
        param(
            [string]$outputFile = "$systemFolder\shell_folder_info.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-StartUpShellFolderInfo {
        param(
            [string]$outputFile = "$systemFolder\startup_shell_folder_info.txt"
        )
        $command = { Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" | Select-Object Startup }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-ApprovedShellExts {
        param(
            [string]$outputFile = "$systemFolder\approved_shell_exts.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-AppCertDlls {
        param(
            [string]$outputFile = "$systemFolder\app_cert_dlls.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCertDlls" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-ExeFileShellCommands {
        param(
            [string]$outputFile = "$systemFolder\exe_file_shell_commands.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SOFTWARE\Classes\exefile\shell\open\command" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-ShellCommands {
        param(
            [string]$outputFile = "$systemFolder\shell_commands.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SOFTWARE\Classes\http\shell\open\command" | Select-Object "(Default)" }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-BcdRelatedData {
        param(
            [string]$outputFile = "$systemFolder\bcd_related_data.txt"
        )
        $command = { Get-ItemProperty "HKLM:\BCD00000000\*\*\*\*" | Select-Object Element | Select-String "exe" | Select-Object Line }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-LoadedLsaPackages {
        param(
            [string]$outputFile = "$systemFolder\loaded_lsa_packages.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-BrowserHelperObjects {
        param(
            [string]$outputFile = "$systemFolder\browser_helper_objects.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\*" | Select-Object "(Default)" }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-BrowserHelperObjectsX64 {
        param(
            [string]$outputFile = "$systemFolder\browser_helper_objects_x64.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\*" | Select-Object "(Default)" }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-IeExtensions {
        param(
            [string]$outputFile = "$systemFolder\ie_extensions.txt"
        )
        Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Internet Explorer\Extensions\*" | Select-Object ButtonText, Icon | Out-File -FilePath $outputFile
        Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Extensions\*" | Select-Object ButtonText, Icon | Out-File -Append -FilePath $outputFile
        Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Extensions\*" | Select-Object ButtonText, Icon | Out-File -Append -FilePath $outputFile
    }


    function Get-UsbDevices {
        param(
            [string]$outputFile = "$systemFolder\usb_devices.txt"
        )
        $command = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\*\*" | Select-Object FriendlyName, PSChildName, ContainerID }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-PnpDevices {
        param(
            [string]$outputFile = "$systemFolder\pnp_devices.csv"
        )
        $command = { Get-PnpDevice }
        $data = &($command)
        Save-OutputAsCsv -Data $data -OutputFile $outputFile
    }


    function Copy-HostFile {
        param(
            [string]$outputFile = "$systemFolder\hosts_file.txt"
        )
        $command = { Get-Content $Env:windir\system32\drivers\etc\hosts }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Copy-ServicesFile {
        param(
            [string]$outputFile = "$systemFolder\services_file.txt"
        )
        $command = { Get-Content $Env:windir\system32\drivers\etc\services }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-AuditPolicy {
        param(
            [string]$outputFile = "$systemFolder\audit_policy.txt"
        )
        $command = { auditpol /get /category:* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-NonValidExes {
        param(
            [string]$outputFile = "$systemFolder\non_valid_exe_files.txt"
        )
        $command = { Get-ChildItem -Force -Recurse -Path "C:\Windows\*\*.exe" -File | Get-AuthenticodeSignature | Where-Object { $_.status -ne "Valid" } }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $workFlow = [ordered]@{
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
        { Get-MappedDrives } = (
            "Getting Mapped Drives...",
            "mapped_drives.txt"
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
            "[installed_apps_list.csv, installed_apps_props.csv, installed_apps_list_wow64.csv, installed_apps_props_wow64.csv]"
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
            "Getting Shell Folder Information...",
            "shell_folder_info.txt"
        )
        { Get-StartUpShellFolderInfo } = (
            "Getting User Startup Shell Folder Information...",
            "startup_shell_folder_info.txt"
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
            "Listing Connected PNP Devices...",
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
    }

    foreach ($task in $workFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
