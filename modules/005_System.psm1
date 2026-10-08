function Get-TriageSystemData {
    [CmdletBinding()]
    param(
        [string]$SystemFolder
    )

    function Get-PnPSignedDrivers {
        param(
            [string]$OutputFile = "$SystemFolder\pnp_signed_drivers.csv"
        )
        $Command = { Get-CimInstance -ClassName Win32_PnPSignedDriver | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
        $ResultCount = ($Data).Count
        Show-Message -Message "There were $ResultCount results returned for this function." -AddToLog
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
            $Command = { [System.IO.Directory]::EnumerateFiles($env:SystemDrive, "*.dll", $Options) |
                Get-Item |
                Select-Object -Property Name, CreationTime, LastAccessTime, Directory |
                Sort-Object -Property CreationTime -Descending |
                Select-Object -First 50 }
            $Data = &($Command)
            Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
        }
        catch [System.IO.IOException] {
            Show-Message -Message "Caught an IO Exception while running $( $MyInvocation.MyCommand.Name ). Error => $( $_.Exception.Message )" -Level ERROR -AddToLog
        }
    }

    function Get-OpenFilesList {
        param(
            [string]$OutputFile = "$SystemFolder\list_of_open_files.txt"
        )
        $Command = { & (Get-TriageBinary "openfiles")  /query }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-OpenShares {
        param(
            [string]$OutputFile = "$SystemFolder\open_shares.txt"
        )
        $Command = { Get-CimInstance -ClassName Win32_Share | Select-Object -Property * | Sort-Object -Property Path }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-LogicalDisks {
        param(
            [string]$OutputFile = "$SystemFolder\logical_disks.csv"
        )
        $Command = { Get-CimInstance -ClassName Win32_LogicalDisk | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-MappedLogicalDisks {
        param(
            [string]$OutputFile = "$SystemFolder\logical_disks_mapped.txt"
        )
        $Command = { Get-CimInstance -ClassName Win32_MappedLogicalDisk | Select-Object -Property * | Format-List }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-ScheduledJobs {
        param(
            [string]$OutputFile = "$SystemFolder\scheduled_jobs.txt"
        )
        $Command = { Get-CimInstance -ClassName Win32_ScheduledJob }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-ScheduledTasks {
        param(
            [string]$OutputFile     = "$SystemFolder\scheduled_task_events.txt",
            [string]$InfoOutputFile = "$SystemFolder\scheduled_task_info.txt"
        )
        $Command1 = { Get-ScheduledTask | Select-Object -Property * | Where-Object { $_.State -ne "Disabled" } | Format-List }
        $Command2 = { Get-ScheduledTask | Where-Object { $_.State -ne "Disabled" } | Get-ScheduledTaskInfo }
        $Data1 = &$Command1
        $Data2 = &$Command2
        Write-OutputToFile -Command $Command1 -Data $Data1 -OutputFile $OutputFile
        Write-OutputToFile -Command $Command2 -Data $Data2 -OutputFile $InfoOutputFile
    }

    function Get-HotFixes {
        param(
            [string]$OutputFile = "$SystemFolder\hot_fixes.csv"
        )
        $Command = { Get-HotFix | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-InstalledApps {
        param(
            [string]$OutputFile = "$SystemFolder\installed_apps.csv"
        )

        # Fixed column list: Export-Csv takes its columns from the FIRST object,
        # so every row must have exactly the same shape
        $Columns = "DisplayName", "DisplayVersion", "Publisher", "InstallDate", "InstallLocation", "InstallSource",
                "EstimatedSize", "UninstallString", "QuietUninstallString", "ModifyPath", "DisplayIcon",
                "URLInfoAbout", "HelpLink", "ParentKeyName", "SystemComponent", "WindowsInstaller", "ReleaseType"

        $Locations = [System.Collections.Generic.List[object]]::new()
        $Locations.Add([pscustomobject]@{
            Scope = "Machine (64-bit)"
            User  = ""
            Sid   = ""
            Path  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
        })
        $Locations.Add([pscustomobject]@{
            Scope = "Machine (32-bit)"
            User  = ""
            Sid   = ""
            Path  = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        })

        # Per-user installs, from the hives the hive step mounted (logged on or not)
        foreach ($H in ($global:TriageUserHives | Where-Object Root)) {
            $Locations.Add([pscustomobject]@{
                Scope = "User"
                User  = $H.UserName
                Sid   = $H.Sid
                Path  = "$( $H.Root )\Software\Microsoft\Windows\CurrentVersion\Uninstall"
            })
            $Locations.Add([pscustomobject]@{
                Scope = "User (32-bit)"
                User  = $H.UserName
                Sid   = $H.Sid
                Path  = "$( $H.Root )\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
            })
        }

        $Rows = foreach ($L in $Locations) {
            if (-not (Test-Path -LiteralPath $L.Path)) { continue }

            foreach ($Key in (Get-ChildItem -LiteralPath $L.Path -ErrorAction SilentlyContinue)) {
                $P   = Get-ItemProperty -LiteralPath $Key.PSPath -ErrorAction SilentlyContinue
                $Row = [ordered]@{
                    Scope = $L.Scope
                    User = $L.User
                    Sid = $L.Sid
                    KeyName = $Key.PSChildName
                }

                foreach ($C in $Columns) {
                    $V = $P.$C
                    $Row[$C] = if ($V -is [array]) {
                        $V -join "; "
                    } else {
                        $V
                    }
                }

                # InstallDate is stored as text (yyyyMMdd); keep it as found and add a parsed copy
                $Parsed = ""
                if ("$( $P.InstallDate )" -match "^\d{8}$") {
                    try {
                        $Parsed = [datetime]::ParseExact("$( $P.InstallDate )", "yyyyMMdd", [System.Globalization.CultureInfo]::InvariantCulture).ToString("yyyy-MM-dd")
                    }
                    catch { }
                }
                $Row["InstallDateParsed"] = $Parsed
                $Row["RegistryPath"]      = $Key.Name

                [pscustomobject]$Row
            }
        }

        # Entries without a DisplayName (patches, components) are kept, because dropping rows from
        # evidence is a decision for the examiner. They sort to the bottom.
        $Sorted = @($Rows) | Sort-Object -Property @{ Expression = { [string]::IsNullOrEmpty($_.DisplayName) } }, DisplayName
        Write-OutputToCsv -Data $Sorted -OutputFile $OutputFile
    }

    function Get-AppxPackages {
        param(
            [string]$OutputFile = "$SystemFolder\appx_packages.csv"
            )
        $Data = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Select-Object Name, Version, Publisher, Architecture, PackageFullName, InstallLocation, SignatureKind, IsFramework, NonRemovable, @{ N = "Users"; E = { @($_.PackageUserInformation | ForEach-Object { "$( $_.UserSecurityId.Username ):$( $_.InstallState )" }) -join "; " } }
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-VolumeShadowCopies {
        param(
            [string]$OutputFile = "$SystemFolder\volume_shadow_copies.csv"
        )
        $Command = { Get-CimInstance -ClassName Win32_ShadowCopy | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-AppInitDllKey {
        param(
            [string]$OutputFile = "$SystemFolder\appinit_dll_key.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" | Select-Object AppInit_DLLs }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-UacGroupPolicy {
        param(
            [string]$OutputFile = "$SystemFolder\uac_group_policy.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" | Select-Object * -ExcludeProperty PS* }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-ActiveSetupInstalls {
        param(
            [string]$OutputFile = "$SystemFolder\active_setup_installs.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\*" | Select-Object ComponentID, Version, "(Default)", StubPath | Format-List }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-AppPathRegKeys {
        param(
            [string]$OutputFile = "$SystemFolder\app_path_reg_keys.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\*" | Select-Object PSChildName, "(Default)" | Format-List }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-DllsLoadedByExplorerShell {
        param(
            [string]$OutputFile = "$SystemFolder\dlls_loaded_by_explorer_shell.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\*\*" | Select-Object "(Default)", DllName }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-ShellAndUserInitValues {
        param(
            [string]$OutputFile = "$SystemFolder\shell_and_user_init_values.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" | Select-Object * -ExcludeProperty PS* }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-SvcValues {
        param(
            [string]$OutputFile = "$SystemFolder\svc_values.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Security Center\Svc" | Select-Object * -ExcludeProperty PS* }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-DesktopAddressBar {
        param(
            [string]$OutputFile = "$SystemFolder\desktop_address_bar.csv"
        )
        Export-PerUserRegistry -OutputFile $OutputFile -SubKey "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths"
    }

    function Get-RunMruKeyInfo {
        param(
            [string]$OutputFile = "$SystemFolder\run_mru_key_info.csv"
        )
        Export-PerUserRegistry -OutputFile $OutputFile -SubKey "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
    }

    function Get-StartMenuData {
        param(
            [string]$OutputFile = "$SystemFolder\start_menu_data.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartMenu" | Select-Object * -ExcludeProperty PS* | Format-List }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-ProgExeBySessionManager {
        param(
            [string]$OutputFile = "$SystemFolder\prog_exe_by_session_manager.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" | Select-Object * -ExcludeProperty PS* }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-ShellFolderInfo {
        param(
            [string]$OutputFile = "$SystemFolder\shell_folders.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-ApprovedShellExts {
        param(
            [string]$OutputFile = "$SystemFolder\approved_shell_exts.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-AppCertDlls {
        param(
            [string]$OutputFile = "$SystemFolder\app_cert_dlls.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCertDlls" }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-ExeFileShellCommands {
        param(
            [string]$OutputFile = "$SystemFolder\exe_file_shell_commands.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Classes\exefile\shell\open\command" }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-ShellCommands {
        param(
            [string]$OutputFile = "$SystemFolder\shell_commands.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Classes\http\shell\open\command" | Select-Object "(Default)" }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-BcdRelatedData {
        param(
            [string]$OutputFile = "$SystemFolder\bcd_related_data.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\BCD00000000\*\*\*\*" | Select-Object Element | Select-String "exe" | Select-Object Line }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-LoadedLsaPackages {
        param(
            [string]$OutputFile = "$SystemFolder\loaded_lsa_packages.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" | Select-Object -Property * }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-BrowserHelperObjects {
        param(
            [string]$OutputFile = "$SystemFolder\browser_helper_objects.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\*" | Select-Object "(Default)" }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-BrowserHelperObjectsX64 {
        param(
            [string]$OutputFile = "$SystemFolder\browser_helper_objects_x64.txt"
        )
        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\*" | Select-Object "(Default)" }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-UsbDevices {
        param(
            [string]$OutputFile1 = "$SystemFolder\usb_devices_from_Enum-USB.csv",
            [string]$OutputFile2 = "$SystemFolder\usb_devices_from_Control-USBSTOR.csv"
        )
        $Command1 = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\USB\*\*" | Select-Object -Property * }
        $Data1 = Invoke-RegistryCommand -Command $Command1
        Write-OutputToCsv -Data $Data1 -OutputFile $OutputFile1

        $Command2 = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\usbstor\*\*" | Select-Object -Property * }
        $Data2 = Invoke-RegistryCommand -Command $Command2
        Write-OutputToCsv -Data $Data2 -OutputFile $OutputFile2
    }

    function Get-PnpDevices {
        param(
            [string]$OutputFile = "$SystemFolder\pnp_devices.csv"
        )
        $Command = { Get-PnpDevice | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Copy-HostFile {
        param(
            [string]$OutputFile = "$SystemFolder\hosts_file.txt"
        )
        $Command = { Get-Content $env:windir\system32\drivers\etc\hosts }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Copy-ServicesFile {
        param(
            [string]$OutputFile = "$SystemFolder\services_file.txt"
        )
        $Command = { Get-Content $env:windir\system32\drivers\etc\services }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-AuditPolicy {
        param(
            [string]$OutputFile = "$SystemFolder\audit_policy.txt"
        )
        $Command = { & (Get-TriageBinary "auditpol")  /get /category:* }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-NonValidExes {
        param(
            [string]$OutputFile = "$SystemFolder\non_valid_exe_files.txt"
        )
        $Command = { Get-ChildItem -Path "$env:SystemDrive\Windows\*\*.exe" -File -Force -Recurse | Get-AuthenticodeSignature | Where-Object { $_.status -ne "Valid" } }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-OptionalFeatures {
        param(
            [string]$OutputFile = "$SystemFolder\optional_features.csv"
        )
        $Data = Get-CimInstance -ClassName Win32_OptionalFeature -ErrorAction SilentlyContinue | Select-Object Name, Caption, @{
                N = "InstallState"
                E = {
                    switch ($_.InstallState) {
                        1 { "Enabled" }
                        2 { "Disabled" }
                        3 { "Absent" }
                        default { $_.InstallState }
                    }
                }
            }
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-ServicingPackages {
        param(
            [string]$OutputFile = "$SystemFolder\servicing_packages.csv"
        )
        $Key  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages"
        $Data = Get-ChildItem -LiteralPath $Key -ErrorAction SilentlyContinue | ForEach-Object {
            $P = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            [pscustomobject]@{
                PackageKey      = $_.PSChildName
                CurrentState    = $P.CurrentState
                InstallClient   = $P.InstallClient
                InstallName     = $P.InstallName
                InstallTimeHigh = $P.InstallTimeHigh
                InstallTimeLow  = $P.InstallTimeLow
            }
        }
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-WmiEventSubscriptions {
        $Ns  = "root\subscription"
        $Sid = { if ($_.CreatorSID) {
                [System.Security.Principal.SecurityIdentifier]::new([byte[]]$_.CreatorSID, 0).Value
            }
        }

        $Filters = Get-CimInstance -Namespace $Ns -ClassName __EventFilter -ErrorAction SilentlyContinue |
            Select-Object Name, Query, QueryLanguage, EventNamespace, @{ N = "CreatorSID"; E = $Sid }

        $Consumers = Get-CimInstance -Namespace $Ns -ClassName __EventConsumer -ErrorAction SilentlyContinue |
            Select-Object @{ N = "ConsumerType"; E = { $_.CimClass.CimClassName } }, Name, CommandLineTemplate, ExecutablePath, WorkingDirectory, ScriptingEngine, ScriptFileName, ScriptText, Filename, Text, SourceName, @{ N = "CreatorSID"; E = $Sid }

        $Bindings = Get-CimInstance -Namespace $Ns -ClassName __FilterToConsumerBinding -ErrorAction SilentlyContinue |
            Select-Object @{ N = "Filter"; E = { $_.Filter.Name } }, @{ N = "Consumer"; E = { $_.Consumer.Name } },
                @{ N = "ConsumerClass"; E = { $_.Consumer.CimClass.CimClassName } }

        Write-OutputToCsv -Data $Filters -OutputFile "$SystemFolder\wmi_event_filters.csv"
        Write-OutputToCsv -Data $Consumers -OutputFile "$SystemFolder\wmi_event_consumers.csv"
        Write-OutputToCsv -Data $Bindings -OutputFile "$SystemFolder\wmi_filter_consumer_bindings.csv"
    }

    function Get-ImageFileExecutionOptions {
        param(
            [string]$OutputFile = "$SystemFolder\image_file_execution_options.csv"
        )
        $Roots = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options",
                "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit"
        $Data = foreach ($Root in $Roots) {
            if (-not (Test-Path -LiteralPath $Root)) { continue }
            foreach ($Key in Get-ChildItem -LiteralPath $Root -ErrorAction SilentlyContinue) {
                $Props = Get-ItemProperty -LiteralPath $Key.PSPath -ErrorAction SilentlyContinue
                foreach ($P in ($Props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" })) {
                    [pscustomobject]@{
                        Root      = $Root -replace "^HKLM:\\", ""
                        Image     = $Key.PSChildName
                        ValueName = $P.Name
                        Data      = ($P.Value -join "; ")
                    }
                }
            }
        }
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-StartupFolderItems {
        param(
            [string]$OutputFile = "$SystemFolder\startup_folder_items.csv"
        )
        $Folders = @([pscustomobject]@{
            User = "ALL USERS"
            Path = Join-Path -Path $env:ProgramData -ChildPath "Microsoft\Windows\Start Menu\Programs\StartUp"
        })
        foreach ($H in ($global:TriageUserHives | Where-Object ProfilePath)) {
            $Folders += [pscustomobject]@{
                User = $H.UserName
                Path = Join-Path -Path $H.ProfilePath -ChildPath "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
            }
        }
        $Data = foreach ($F in $Folders) {
            if (-not (Test-Path -LiteralPath $F.Path)) { continue }
            Get-ChildItem -LiteralPath $F.Path -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object {
                [pscustomobject]@{
                    User        = $F.User
                    FullName    = $_.FullName
                    Length      = $_.Length
                    CreatedUtc  = $_.CreationTimeUtc.ToString("o")
                    ModifiedUtc = $_.LastWriteTimeUtc.ToString("o")
                    SHA256      = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
                }
            }
        }
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-BitsJobs {
        param(
            [string]$OutputFile = "$SystemFolder\bits_jobs.csv"
        )
        # Querying BITS can start the service, which would change the target. Only query it if it is already running.
        $Svc = Get-Service -Name BITS -ErrorAction SilentlyContinue
        if (-not $Svc -or $Svc.Status -ne "Running") {
            Write-OutputToCsv -Data ([pscustomobject]@{
                Note = "BITS service was not running; jobs not queried. See the BITS database copy in 011_Raw_Artifacts."
            }) -OutputFile $OutputFile
            return
        }
        $Data = Get-BitsTransfer -AllUsers -ErrorAction Stop |
            Select-Object -Property *, @{ N = "Files"; E = { @($_.FileList | ForEach-Object { "$($_.RemoteName) -> $($_.LocalName)" }) -join "; " } } -ExcludeProperty FileList
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $Tasks = @(
        # @{
        #     Action  = { Get-Last50Dlls }
        #     Message = "Getting Last 50 Created .dll Files..."
        #     Files   = "last_50_dll_files.txt"
        # }
        @{
            Action  = { Get-PnPSignedDrivers }
            Message = "Gathering Driver Info for PnP Devices..."
            Files   = "pnp_signed_drivers.csv"
        }
        @{
            Action  = { Get-OpenFilesList }
            Message = "Processing List of Open Files..."
            Files   = "list_of_open_files.txt"
        }
        @{
            Action  = { Get-OpenShares }
            Message = "Getting Open Shares..."
            Files   = "open_shares.txt"
        }
        @{
            Action  = { Get-LogicalDisks }
            Message = "Getting Logical Drives..."
            Files   = "logical_disks.csv"
        }
        @{
            Action  = { Get-MappedLogicalDisks }
            Message = "Getting Mapped Logical Disks..."
            Files   = "logical_disks_mapped.txt"
        }
        @{
            Action  = { Get-ScheduledJobs }
            Message = "Listing Scheduled Jobs..."
            Files   = "scheduled_jobs.txt"
        }
        @{
            Action  = { Get-ScheduledTasks }
            Message = "Getting Scheduled Tasks and Task Info..."
            Files   = "scheduled_task_events.txt", "scheduled_task_info.txt"
        }
        @{
            Action  =  { Get-HotFixes }
            Message = "Listing Applied HotFixes..."
            Files   = "hot_fixes.csv"
        }
        @{
            Action  =  { Get-InstalledApps }
            Message = "Getting Installed Applications..."
            Files   = "installed_apps.csv"
        }
        @{
            Action = { Get-AppxPackages }
            Message = "Getting AppX packages..."
            Files = "appx_packages.csv"
        }
        @{
            Action  = { Get-VolumeShadowCopies }
            Message = "Listing Volume Shadow Copies..."
            Files   = "volume_shadow_copies.csv"
        }
        @{
            Action  = { Get-AppInitDllKey }
            Message = "Getting AppInit_DLL Registry Keys..."
            Files   = "appinit_dll_key.txt"
        }
        @{
            Action  = { Get-UacGroupPolicy }
            Message = "Listing UAC Group Policy Settings..."
            Files   = "uac_group_policy.txt"
        }
        @{
            Action  = { Get-ActiveSetupInstalls }
            Message = "Getting Active Setup Installs..."
            Files   = "active_setup_installs.txt"
        }
        @{
            Action  = { Get-AppPathRegKeys }
            Message = "Getting App Path Registry Keys..."
            Files   = "app_path_reg_keys.txt"
        }
        @{
            Action  = { Get-DllsLoadedByExplorerShell }
            Message = "Listing .dll Files Loaded by Explorer.exe Shell..."
            Files   = "dlls_loaded_by_explorer_shell.txt"
        }
        @{
            Action  = { Get-ShellAndUserInitValues }
            Message = "Getting Shell and UserInit Values..."
            Files   = "shell_and_user_init_values.txt"
        }
        @{
            Action  = { Get-SvcValues }
            Message = "Listing Security Center SVC Values..."
            Files   = "svc_values.txt"
        }
        @{
            Action  = { Get-DesktopAddressBar }
            Message = "Parsing Desktop Address Bar History..."
            Files   = "desktop_address_bar.csv"
        }
        @{
            Action  = { Get-RunMruKeyInfo }
            Message = "Getting RunMRU key Information..."
            Files   = "run_mru_key_info.csv"
        }
        @{
            Action  = { Get-StartMenuData }
            Message = "Listing Start Menu Data..."
            Files   = "start_menu_data.txt"
        }
        @{
            Action  = { Get-ProgExeBySessionManager }
            Message = "Listing Programs Executed by Session Manager..."
            Files   = "prog_exe_by_session_manager.txt"
        }
        @{
            Action  = { Get-ShellFolderInfo }
            Message = "Getting User Startup Shell Folder Information..."
            Files   = "shell_folders.txt"
        }
        @{
            Action  = { Get-ApprovedShellExts }
            Message = "Listing Approved Shell Extensions..."
            Files   = "approved_shell_exts.txt"
        }
        @{
            Action  = { Get-AppCertDlls }
            Message = "Listing AppCert .dll Files..."
            Files   = "app_cert_dlls.txt"
        }
        @{
            Action  = { Get-ExeFileShellCommands }
            Message = "Listing .exe File Shell Command Configuration..."
            Files   = "exe_file_shell_commands.txt"
        }
        @{
            Action  = { Get-ShellCommands }
            Message = "Listing Shell Commands..."
            Files   = "shell_commands.txt"
        }
        @{
            Action  = { Get-BcdRelatedData }
            Message = "Getting BCD Related Data..."
            Files   = "bcd_related_data.txt"
        }
        @{
            Action  = { Get-LoadedLsaPackages }
            Message = "Reading Loaded LSA Packages Data..."
            Files   = "loaded_lsa_packages.txt"
        }
        @{
            Action  = { Get-BrowserHelperObjects }
            Message = "Parsing Browser Helper Objects..."
            Files   = "browser_helper_objects.txt"
        }
        @{
            Action  = { Get-BrowserHelperObjectsX64 }
            Message = "Parsing Browser Helper Objects (64 Bit)..."
            Files   = "browser_helper_objects_x64.txt"
        }
        @{
            Action  = { Get-UsbDevices }
            Message = "Listing Connected USB Devices..."
            Files   = "usb_devices_from_Enum-USB.csv", "usb_devices_from_Control-USBSTOR.csv"
        }
        @{
            Action  = { Get-PnpDevices }
            Message = "Listing Connected PnP Devices..."
            Files   = "pnp_devices.csv"
        }
        @{
            Action  = { Copy-HostFile }
            Message = "Copying *hosts* File..."
            Files   = "hosts_file.txt"
        }
        @{
            Action  = { Copy-ServicesFile }
            Message = "Copying *services* File..."
            Files   = "services_file.txt"
        }
        @{
            Action  = { Get-AuditPolicy }
            Message = "Listing Computer Audit Policy..."
            Files   = "audit_policy.txt"
        }
        @{
            Action  = { Get-NonValidExes }
            Message = "Listing Executables Without Valid Authenticode Signature..."
            Files   = "non_valid_exe_files.txt"
        }
        @{
            Action  = { Get-OptionalFeatures }
            Message = "Gathering Optional Features..."
            Files   = "optional_features.csv"
        }
        @{
            Action  = { Get-ServicingPackages }
            Message = "Gathering Service Packages..."
            Files   = "servicing_packages.csv"
        }
        @{
            Action = { Get-WmiEventSubscriptions }
            Message = "Getting WMI event subscriptions..."
            Files = "wmi_event_filters.csv", "wmi_event_consumers.csv", "wmi_filter_consumer_bindings.csv"
        }
        @{
            Action = { Get-ImageFileExecutionOptions }
            Message = "Getting Image File Execution Options..."
            Files = "image_file_execution_options.csv"
        }
        @{
            Action = { Get-StartupFolderItems }
            Message = "Getting startup folder contents..."
            Files = "startup_folder_items.csv"
        }
        @{
            Action = { Get-BitsJobs }
            Message = "Getting BITS jobs..."
            Files = "bits_jobs.csv"
        }

    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $SystemFolder
}
