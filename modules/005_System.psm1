function Get-TriageSystemData
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SystemFolder
    )

    begin
    {
        function Get-PnPSignedDrivers
        {
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "pnp_signed_drivers.csv")
            )

            $Data = Get-CimInstance -ClassName Win32_PnPSignedDriver |
                Select-Object -Property *
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
            $ResultCount = ($Data).Count
            Show-Message -Message "There were $ResultCount results returned for this function." -AddToLog
        }

        function Get-Last50Dlls
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "last_50_dll_files.txt")
            )

            try
            {
                # Set up the .NET directory enumeration rules
                $Options = [System.IO.EnumerationOptions]::new()
                $Options.RecurseSubdirectories = $true
                $Options.AttributesToSkip = [System.IO.FileAttributes]::None
                $Options.IgnoreInaccessible = $true
                $Data = [System.IO.Directory]::EnumerateFiles($env:SystemDrive, "*.dll", $Options) |
                    Get-Item |
                    Select-Object -Property Name, CreationTime, LastAccessTime, Directory |
                    Sort-Object -Property CreationTime -Descending |
                    Select-Object -First 50
                Write-OutputToFile -Data $Data -OutputFile $TxtFile
            }
            catch [System.IO.IOException]
            {
                Show-Message -Message "Caught an IO Exception while running $( $MyInvocation.MyCommand.Name ). Error => $( $_.Exception.Message )" -Level ERROR -AddToLog
            }
        }

        function Get-OpenFilesList
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "list_of_open_files.txt")
            )

            $Data = & (Get-TriageBinary "openfiles") /query /FO CSV
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-OpenShares
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "open_shares.txt")
            )

            $Data = Get-CimInstance -ClassName Win32_Share |
                Select-Object -Property * |
                Sort-Object -Property Path
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-LogicalDisks
        {
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "logical_disks.csv")
            )

            $Data = Get-CimInstance -ClassName Win32_LogicalDisk |
                Select-Object -Property *
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-MappedLogicalDisks
        {
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "logical_disks_mapped.txt")
            )

            $Data = Get-CimInstance -ClassName Win32_MappedLogicalDisk |
                Select-Object -Property * |
                Format-List
            Write-OutputToFile -Data $Data -OutputFile $CsvFile
        }

        function Get-ScheduledJobs
        {
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "scheduled_jobs.txt")
            )

            $Data = Get-CimInstance -ClassName Win32_ScheduledJob
            Write-OutputToFile -Data $Data -OutputFile $CsvFile
        }

        function Get-ScheduledTasks
        {
            param(
                [string]$TxtFile     = (Join-Path -Path $SystemFolder -ChildPath "scheduled_task_events.txt"),
                [string]$TxtInfoFile = (Join-Path -Path $SystemFolder -ChildPath "scheduled_task_info.txt")
            )

            $Data1 = Get-ScheduledTask |
                Select-Object -Property * |
                Where-Object { $_.State -ne "Disabled" } |
                Format-List
            $Data2 = Get-ScheduledTask |
                Where-Object { $_.State -ne "Disabled" } |
                Get-ScheduledTaskInfo

            Write-OutputToFile -Data $Data1 -OutputFile $TxtFile
            Write-OutputToFile -Data $Data2 -OutputFile $TxtInfoFile
        }

        function Get-HotFixes
        {
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "hot_fixes.csv")
            )

            $Data = Get-HotFix | Select-Object -Property *
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-InstalledApps
        {
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "installed_apps.csv")
            )

            # Fixed column list: Export-Csv takes its columns from the FIRST object,
            # so every row must have exactly the same shape
            $Columns = "DisplayName", "DisplayVersion", "Publisher", "InstallDate",
                    "InstallLocation", "InstallSource", "EstimatedSize", "UninstallString",
                    "QuietUninstallString", "ModifyPath", "DisplayIcon", "URLInfoAbout",
                    "HelpLink", "ParentKeyName", "SystemComponent", "WindowsInstaller", "ReleaseType"

            $Locations = [System.Collections.Generic.List[object]]::new()
            $Locations.Add([PSCustomObject]@{
                Scope = "Machine (64-bit)"
                User  = ""
                Sid   = ""
                Path  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
            })
            $Locations.Add([PSCustomObject]@{
                Scope = "Machine (32-bit)"
                User  = ""
                Sid   = ""
                Path  = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
            })

            # Per-user installs, from the hives the hive step mounted (logged on or not)
            foreach ($H in ($global:TriageUserHives | Where-Object Root))
            {
                $Locations.Add([PSCustomObject]@{
                    Scope = "User"
                    User  = $H.UserName
                    Sid   = $H.Sid
                    Path  = "$( $H.Root )\Software\Microsoft\Windows\CurrentVersion\Uninstall"
                })
                $Locations.Add([PSCustomObject]@{
                    Scope = "User (32-bit)"
                    User  = $H.UserName
                    Sid   = $H.Sid
                    Path  = "$( $H.Root )\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
                })
            }

            $Rows = foreach ($L in $Locations)
            {
                if (-not (Test-Path -LiteralPath $L.Path))
                {
                    continue
                }

                foreach ($Key in (Get-ChildItem -LiteralPath $L.Path -ErrorAction SilentlyContinue))
                {
                    $P   = Get-ItemProperty -LiteralPath $Key.PSPath -ErrorAction SilentlyContinue
                    $Row = [ordered]@{
                        Scope = $L.Scope
                        User = $L.User
                        Sid = $L.Sid
                        KeyName = $Key.PSChildName }

                    foreach ($C in $Columns)
                    {
                        $V = $P.$C
                        $Row[$C] = if ($V -is [array])
                        {
                            $V -join "; "
                        }
                        else
                        {
                            $V
                        }
                    }

                    # InstallDate is stored as text (yyyyMMdd); keep it as found and add a parsed copy
                    $Parsed = ""
                    if ("$( $P.InstallDate )" -match "^\d{8}$")
                    {
                        try
                        {
                            $Parsed = [datetime]::ParseExact("$( $P.InstallDate )", "yyyyMMdd", [System.Globalization.CultureInfo]::InvariantCulture).ToString("yyyy-MM-dd")
                        }
                        catch { }
                    }

                    $Row["InstallDateParsed"] = $Parsed
                    $Row["RegistryPath"]      = $Key.Name

                    [PSCustomObject]$Row
                }
            }

            # Entries without a DisplayName (patches, components) are kept, because dropping rows from
            # evidence is a decision for the examiner. They sort to the bottom.
            $Sorted = @($Rows) | Sort-Object -Property @{ Expression = { [string]::IsNullOrEmpty($_.DisplayName) } }, DisplayName
            Write-OutputToCsv -Data $Sorted -OutputFile $CsvFile
        }

        function Get-AppxPackages
        {
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "appx_packages.csv")
                )

            $Data = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
                Select-Object -Property Name, Version, Publisher, Architecture, PackageFullName, InstallLocation, SignatureKind, IsFramework, NonRemovable, @{ Name = "Users"; Expression = { @($_.PackageUserInformation |
                ForEach-Object { "$( $_.UserSecurityId.Username ):$( $_.InstallState )" }) -join "; " } }
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-VolumeShadowCopies
        {
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "volume_shadow_copies.csv")
            )

            $Data = Get-CimInstance -ClassName Win32_ShadowCopy | Select-Object -Property *
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-AppInitDllKey
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "appinit_dll_key.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" |
                Select-Object AppInit_DLLs
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-UacGroupPolicy
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "uac_group_policy.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" |
                Select-Object * -ExcludeProperty PS*
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-ActiveSetupInstalls
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "active_setup_installs.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\*" |
                Select-Object ComponentID, Version, "(Default)", StubPath |
                Format-List
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-AppPathRegKeys
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "app_path_reg_keys.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\*" |
                Select-Object PSChildName, "(Default)" |
                Format-List
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-DllsLoadedByExplorerShell
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "dlls_loaded_by_explorer_shell.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\*\*" |
                Select-Object "(Default)", DllName
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-ShellAndUserInitValues
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "shell_and_user_init_values.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" |
                Select-Object * -ExcludeProperty PS*
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-SvcValues
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "svc_values.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Security Center\Svc" |
                Select-Object * -ExcludeProperty PS*
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-DesktopAddressBar
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "desktop_address_bar.csv")
            )

            Export-PerUserRegistry -OutputFile $TxtFile -SubKey "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths"
        }

        function Get-RunMruKeyInfo
        {
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "run_mru_key_info.csv")
            )

            Export-PerUserRegistry -OutputFile $CsvFile -SubKey "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
        }

        function Get-StartMenuData
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "start_menu_data.txt")
            )

            $Data = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartMenu" |
                Select-Object * -ExcludeProperty PS* |
                Format-List
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-ProgExeBySessionManager
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "prog_exe_by_session_manager.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" |
                Select-Object * -ExcludeProperty PS*
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-ShellFolderInfo
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "shell_folders.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-ApprovedShellExts
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "approved_shell_exts.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved"
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-AppCertDlls
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "app_cert_dlls.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCertDlls"
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-ExeFileShellCommands
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "exe_file_shell_commands.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SOFTWARE\Classes\exefile\shell\open\command"
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-ShellCommands
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "shell_commands.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SOFTWARE\Classes\http\shell\open\command" |
                Select-Object "(Default)"
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-BcdRelatedData
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "bcd_related_data.txt")
            )

            $Command = Get-ItemProperty "HKLM:\BCD00000000\*\*\*\*" |
                Select-Object Element |
                Select-String "exe" |
                Select-Object Line
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-LoadedLsaPackages
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "loaded_lsa_packages.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" |
                Select-Object -Property *
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-BrowserHelperObjects
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "browser_helper_objects.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\*" | Select-Object "(Default)"
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-BrowserHelperObjectsX64
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "browser_helper_objects_x64.txt")
            )

            $Command = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\*" | Select-Object "(Default)"
            $Data = Invoke-RegistryCommand -Command $Command
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-UsbDevices
        {
            param(
                [string]$CsvFile1 = (Join-Path -Path $SystemFolder -ChildPath "usb_devices_from_Enum-USB.csv"),
                [string]$CsvFile2 = (Join-Path -Path $SystemFolder -ChildPath "usb_devices_from_Control-USBSTOR.csv")
            )

            $Command1 = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\USB\*\*" | Select-Object -Property * }
            $Data1 = Invoke-RegistryCommand -Command $Command1
            Write-OutputToCsv -Data $Data1 -OutputFile $CsvFile1

            $Command2 = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\usbstor\*\*" | Select-Object -Property * }
            $Data2 = Invoke-RegistryCommand -Command $Command2
            Write-OutputToCsv -Data $Data2 -OutputFile $CsvFile2
        }

        function Get-PnpDevices
        {
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "pnp_devices.csv")
            )

            $Data = Get-PnpDevice | Select-Object -Property *
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Copy-HostFile
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "hosts_file.txt")
            )

            $Data = Get-Content $env:windir\system32\drivers\etc\hosts
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Copy-ServicesFile
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "services_file.txt")
            )

            $Data = Get-Content $env:windir\system32\drivers\etc\services
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-AuditPolicy
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "audit_policy.txt")
            )

            $Data = & (Get-TriageBinary "auditpol") /get /category:*
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-NonValidExes
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "non_valid_exe_files.txt")
            )

            $Data = Get-ChildItem -Path "$env:SystemDrive\Windows\*\*.exe" -File -Force -Recurse |
                Get-AuthenticodeSignature |
                Where-Object { $_.status -ne "Valid" }
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-OptionalFeatures
        {
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "optional_features.csv")
            )

            $Data = Get-CimInstance -ClassName Win32_OptionalFeature -ErrorAction SilentlyContinue | Select-Object Name, Caption, @{
                    N = "InstallState"
                    E = {
                        switch ($_.InstallState)
                        {
                            1 { "Enabled" }
                            2 { "Disabled" }
                            3 { "Absent" }
                            default { $_.InstallState }
                        }
                    }
                }
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-ServicingPackages
        {
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "servicing_packages.csv")
            )

            $Key  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages"
            $Data = Get-ChildItem -LiteralPath $Key -ErrorAction SilentlyContinue |
                ForEach-Object {
                    $P = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
                    [PSCustomObject]@{
                        PackageKey      = $_.PSChildName
                        CurrentState    = $P.CurrentState
                        InstallClient   = $P.InstallClient
                        InstallName     = $P.InstallName
                        InstallTimeHigh = $P.InstallTimeHigh
                        InstallTimeLow  = $P.InstallTimeLow
                    }
                }
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-WmiEventSubscriptions
        {
            param(
                [string]$CsvFile1 = (Join-Path -Path $SystemFolder -ChildPath "wmi_event_filters.csv"),
                [string]$CsvFile2 = (Join-Path -Path $SystemFolder -ChildPath "wmi_event_consumers.csv"),
                [string]$CsvFile3 = (Join-Path -Path $SystemFolder -ChildPath "wmi_filter_consumer_bindings.csv")
            )

            $Ns  = "root\subscription"
            $Sid = { if ($_.CreatorSID)
                {
                    [System.Security.Principal.SecurityIdentifier]::new([byte[]]$_.CreatorSID, 0).Value
                }
            }

            $Filters = Get-CimInstance -Namespace $Ns -ClassName __EventFilter -ErrorAction SilentlyContinue |
                Select-Object Name, Query, QueryLanguage, EventNamespace, @{ Name = "CreatorSID"; Expression = $Sid }

            $Consumers = Get-CimInstance -Namespace $Ns -ClassName __EventConsumer -ErrorAction SilentlyContinue |
                Select-Object @{ Name = "ConsumerType"; Expression = { $_.CimClass.CimClassName } }, Name, CommandLineTemplate, ExecutablePath, WorkingDirectory, ScriptingEngine, ScriptFileName, ScriptText, Filename, Text, SourceName, @{ Name = "CreatorSID"; Expression = $Sid }

            $Bindings = Get-CimInstance -Namespace $Ns -ClassName __FilterToConsumerBinding -ErrorAction SilentlyContinue |
                Select-Object @{ Name = "Filter"; Expression = { $_.Filter.Name } }, @{ Name = "Consumer"; Expression = { $_.Consumer.Name } }, @{ Name = "ConsumerClass"; Expression = { $_.Consumer.CimClass.CimClassName } }

            Write-OutputToCsv -Data $Filters -OutputFile $CsvFile1
            Write-OutputToCsv -Data $Consumers -OutputFile $CsvFile2
            Write-OutputToCsv -Data $Bindings -OutputFile $CsvFile3
        }

        function Get-ImageFileExecutionOptions
        {
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "image_file_execution_options.csv")
            )

            $Roots = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options",
                    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options",
                    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit"
            $Data = foreach ($Root in $Roots)
            {
                if (-not (Test-Path -LiteralPath $Root))
                {
                    continue
                }
                foreach ($Key in Get-ChildItem -LiteralPath $Root -ErrorAction SilentlyContinue)
                {
                    $Props = Get-ItemProperty -LiteralPath $Key.PSPath -ErrorAction SilentlyContinue
                    foreach ($P in ($Props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" }))
                    {
                        [PSCustomObject]@{
                            Root      = $Root -replace "^HKLM:\\", ""
                            Image     = $Key.PSChildName
                            ValueName = $P.Name
                            Data      = ($P.Value -join "; ")
                        }
                    }
                }
            }
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-StartupFolderItems
        {
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "startup_folder_items.csv")
            )

            $Folders = @([PSCustomObject]@{
                User = "ALL USERS"
                Path = Join-Path -Path $env:ProgramData -ChildPath "Microsoft\Windows\Start Menu\Programs\StartUp"
            })
            foreach ($H in ($global:TriageUserHives | Where-Object ProfilePath))
            {
                $Folders += [PSCustomObject]@{
                    User = $H.UserName
                    Path = Join-Path -Path $H.ProfilePath -ChildPath "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
                }
            }
            $Data = foreach ($F in $Folders)
            {
                if (-not (Test-Path -LiteralPath $F.Path))
                {
                    continue
                }
                Get-ChildItem -LiteralPath $F.Path -Recurse -Force -File -ErrorAction SilentlyContinue |
                    ForEach-Object {
                    [PSCustomObject]@{
                        User        = $F.User
                        FullName    = $_.FullName
                        Length      = $_.Length
                        CreatedUtc  = $_.CreationTimeUtc.ToString("o")
                        ModifiedUtc = $_.LastWriteTimeUtc.ToString("o")
                        SHA256      = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
                    }
                }
            }
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-BitsJobs
        {
        <#
        .SYNOPSIS
            Querying BITS can start the service, which would change the target.
            Only query it if it is already running.
        #>
            param(
                [string]$CsvFile = (Join-Path -Path $SystemFolder -ChildPath "bits_jobs.csv")
            )

            $Svc = Get-Service -Name BITS -ErrorAction SilentlyContinue
            if (-not $Svc -or $Svc.Status -ne "Running")
            {
                Write-OutputToCsv -Data ([PSCustomObject]@{
                    Note = "BITS service was not running; jobs not queried. See the BITS database copy in 011_Raw_Artifacts."
                }) -OutputFile $CsvFile
                return
            }
            $Data = Get-BitsTransfer -AllUsers -ErrorAction Stop |
                Select-Object -Property *, @{ Name = "Files"; Expression = { @($_.FileList | ForEach-Object { "$( $_.RemoteName ) -> $( $_.LocalName )" }) -join "; " } } -ExcludeProperty FileList
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-DownloadedExecutables
        {
            param(
                [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "downloaded_executables.txt")
            )

            $Data = Get-ChildItem -LiteralPath $env:SystemDrive -Recurse -Force -Include $ExecutableFileTypes |
                ForEach-Object { $P = $_.FullName; Get-Item $P -Stream * } |
                Where-Object { $_.Stream -match "Zone.Identifier" } |
                Select-Object Filename, Stream, @{ Name = "LastWriteTime"; Expression = { (Get-ChildItem $P).LastWriteTime } }
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }
    }
    process {
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
                Action  = { Get-AppxPackages }
                Message = "Getting AppX packages..."
                Files   = "appx_packages.csv"
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
                Action  = { Get-WmiEventSubscriptions }
                Message = "Getting WMI event subscriptions..."
                Files   = "wmi_event_filters.csv", "wmi_event_consumers.csv", "wmi_filter_consumer_bindings.csv"
            }
            @{
                Action  = { Get-ImageFileExecutionOptions }
                Message = "Getting Image File Execution Options..."
                Files   = "image_file_execution_options.csv"
            }
            @{
                Action  = { Get-StartupFolderItems }
                Message = "Getting startup folder contents..."
                Files   = "startup_folder_items.csv"
            }
            @{
                Action  = { Get-BitsJobs }
                Message = "Getting BITS jobs..."
                Files   = "bits_jobs.csv"
            }
            @{
                Action  = { Get-DownloadedExecutables }
                Message = "Getting downloaded executables..."
                Files   = "downloaded_executables.txt"
            }
        )
        Invoke-TriageTaskList -Tasks $Tasks -Folder $SystemFolder
    }
}
