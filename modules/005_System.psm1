function Get-TriageSystemData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SystemFolder
    )

    # 05.01
    function Get-PnPSignedDrivers {
        param([string]$OutputFile)

        $Data = Get-CimInstance -ClassName Win32_PnPSignedDriver |
            Select-Object -Property *
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile

        $Msg = ("There were {0} results returned for this function." -f $Data.Count)
        Show-Message -Message $Msg -Level INFO -AddToLog
    }


    # 05.02
    function Get-OpenShares {
        param([string]$OutputFile)

        $Data = Get-CimInstance -ClassName Win32_Share |
            Select-Object -Property * |
            Sort-Object -Property Path
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.03
    function Get-LogicalDisks {
        param([string]$OutputFile)

        $Data = Get-CimInstance -ClassName Win32_LogicalDisk |
            Select-Object -Property *
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # 05.04
    function Get-MappedLogicalDisks {
        param([string]$OutputFile)

        $Data = Get-CimInstance -ClassName Win32_MappedLogicalDisk |
            Select-Object -Property * |
            Format-List
        Write-OutputToFile -Data $Data -OutputFile $CsvFile
    }


    # 05.05
    function Get-ScheduledJobs {
        param([string]$OutputFile)

        $Data = Get-CimInstance -ClassName Win32_ScheduledJob
        Write-OutputToFile -Data $Data -OutputFile $CsvFile
    }


    # 05.06
    function Get-ScheduledTasks {
        param([string[]]$OutputFiles)

        $Data1 = Get-ScheduledTask |
            Select-Object -Property * |
            Where-Object { $_.State -ne "Disabled" } |
            Format-List
        $Data2 = Get-ScheduledTask |
            Where-Object { $_.State -ne "Disabled" } |
            Get-ScheduledTaskInfo

        Write-OutputToFile -Data $Data1 -OutputFile $OutputFiles[0]
        Write-OutputToFile -Data $Data2 -OutputFile $OutputFiles[1]
    }


    # 05.07
    function Get-HotFixes {
        param([string]$OutputFile)
        $Data = Get-HotFix | Select-Object -Property *
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # 05.08
    function Get-InstalledApps {
        param([string]$OutputFile)
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
        foreach ($H in ($global:TriageUserHives | Where-Object Root)) {
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

        $Rows = foreach ($L in $Locations) {
            if (-not (Test-Path -LiteralPath $L.Path)) {
                continue
            }

            foreach ($Key in (Get-ChildItem -LiteralPath $L.Path )) {
                $P   = Get-ItemProperty -LiteralPath $Key.PSPath
                $Row = [ordered]@{
                    Scope = $L.Scope
                    User = $L.User
                    Sid = $L.Sid
                    KeyName = $Key.PSChildName }

                foreach ($C in $Columns) {
                    $V = $P.$C
                    $Row[$C] = if ($V -is [array]) {
                        $V -join "; "
                    }
                    else {
                        $V
                    }
                }

                # InstallDate is stored as text (yyyyMMdd); keep it as found and add a parsed copy
                $Parsed = ""
                if ("$( $P.InstallDate )" -match "^\d{8}$") {
                    try {
                        $Parsed = [datetime]::ParseExact("$( $P.InstallDate )", "yyyyMMdd", `
                        [System.Globalization.CultureInfo]::InvariantCulture).ToString("yyyy-MM-dd")
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
        $Sorted = @(
            $Rows) |
            Sort-Object -Property @{
                Expression = { [string]::IsNullOrEmpty($_.DisplayName) }
            }, DisplayName
        Write-OutputToCsv -Data $Sorted -OutputFile $OutputFile
    }


    # 05.09
    function Get-AppxPackages {
        param([string]$OutputFile)

        $Data = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
            Select-Object -Property Name, Version, Publisher, Architecture,
            PackageFullName, InstallLocation, SignatureKind, IsFramework,
            NonRemovable, @{
                Name = "Users"
                Expression = { @($_.PackageUserInformation |
                    ForEach-Object {
                        "$( $_.UserSecurityId.Username ):$( $_.InstallState )"
                    }) -join "; "
                }
            }
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # 05.10
    function Get-VolumeShadowCopies {
        param([string]$OutputFile)

        $Data = Get-CimInstance -ClassName Win32_ShadowCopy | Select-Object -Property *
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # 05.11
    function Get-AppInitDllKey {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" |
            Select-Object AppInit_DLLs }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.12
    function Get-UacGroupPolicy {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" |
            Select-Object -Property * -ExcludeProperty PS* }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.13
    function Get-ActiveSetupInstalls {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\*" |
            Select-Object ComponentID, Version, "(Default)", StubPath | Format-List }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.14
    function Get-AppPathRegKeys {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\*" | Select-Object PSChildName, "(Default)" | Format-List }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.15
    function Get-DllsLoadedByExplorerShell {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\*\*" |
            Select-Object "(Default)", DllName }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.16
    function Get-ShellAndUserInitValues {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" |
            Select-Object -Property * -ExcludeProperty PS* }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.17
    function Get-SvcValues {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Security Center\Svc" |
            Select-Object -Property * -ExcludeProperty PS* }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.18
    function Get-DesktopAddressBar {
        param(
            [string]$OutputFile,
            [string]$SubKey = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths"
        )

        Export-PerUserRegistry -OutputFile $OutputFile -SubKey $SubKey
    }


    # 05.19
    function Get-RunMruKeyInfo {
        param(
            [string]$OutputFile,
            [string]$SubKey = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
        )

        Export-PerUserRegistry -OutputFile $OutputFile -SubKey $SubKey
    }


    # 05.20
    function Get-StartMenuData {
        param([string]$OutputFile)

        $Data = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartMenu" |
            Select-Object -Property * -ExcludeProperty PS* |
            Format-List
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.21
    function Get-ProgExeBySessionManager {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" |
            Select-Object -Property * -ExcludeProperty PS* }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.22
    function Get-ShellFolderInfo {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.23
    function Get-ApprovedShellExts {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.24
    function Get-AppCertDlls {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCertDlls" }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.25
    function Get-ExeFileShellCommands {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Classes\exefile\shell\open\command" }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.26
    function Get-ShellCommands {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Classes\http\shell\open\command" | Select-Object "(Default)" }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.27
    function Get-BcdRelatedData {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\BCD00000000\*\*\*\*" | Select-Object Element | Select-String "exe" | Select-Object Line }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.28
    function Get-LoadedLsaPackages {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" | Select-Object -Property * }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.29
    function Get-BrowserHelperObjects {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\*" | Select-Object "(Default)" }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.30
    function Get-BrowserHelperObjectsX64 {
        param([string]$OutputFile)

        $Command = { Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\*" | Select-Object "(Default)" }
        $Data = Invoke-RegistryCommand -Command $Command
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    #  05.31
    function Get-UsbDevices {
        param([string[]]$OutputFiles)

        $Command1 = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\USB\*\*" |
            Select-Object -Property * }
        $Data1 = Invoke-RegistryCommand -Command $Command1
        Write-OutputToCsv -Data $Data1 -OutputFile $OutputFiles[0]

        $Command2 = { Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\usbstor\*\*" |
            Select-Object -Property * }
        $Data2 = Invoke-RegistryCommand -Command $Command2
        Write-OutputToCsv -Data $Data2 -OutputFile $OutputFiles[1]
    }


    # 05.32
    function Get-PnpDevices {
        param([string]$OutputFile)

        $Data = Get-PnpDevice | Select-Object -Property *
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # 05.33
    function Copy-HostFile {
        param([string]$OutputFile)

        $Data = Get-Content $env:windir\system32\drivers\etc\hosts
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.34
    function Copy-ServicesFile {
        param([string]$OutputFile)

        $Data = Get-Content $env:windir\system32\drivers\etc\services
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.35
    function Get-AuditPolicy {
        param([string]$OutputFile)

        $Data = & (Get-TriageBinary "auditpol") /get /category:*
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.36
    function Get-NonValidExes {
        param([string]$OutputFile)

        $Folders = foreach ($Sub in (Get-TriageConfig -Key "ScanFolders").SystemExeFolders) {
            Join-Path -Path "$env:SystemDrive\" -ChildPath $Sub
        }
        $Data = Get-ChildItem -LiteralPath $Folders -Filter "*.exe" -File -Force `
            -ErrorAction SilentlyContinue |
            Get-AuthenticodeSignature |
            Where-Object { $_.status -ne "Valid" }
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.37
    function Get-OptionalFeatures {
        param([string]$OutputFile)
        $Data = Get-CimInstance -ClassName Win32_OptionalFeature |
            Select-Object Name, Caption, @{
                Name       = "InstallState"
                Expression = {
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


    # 05.38
    function Get-ServicingPackages {
        param([string]$OutputFile)
        $Key  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages"
        $Data = Get-ChildItem -LiteralPath $Key |
            ForEach-Object {
                $P = Get-ItemProperty -LiteralPath $_.PSPath
                [PSCustomObject]@{
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


    # 05.39
    function Get-WmiEventSubscriptions {
        param([string[]]$OutputFiles)

        $Ns  = "root\subscription"
        $Sid = { if ($_.CreatorSID) {
                [System.Security.Principal.SecurityIdentifier]::new([byte[]]$_.CreatorSID, 0).Value
            }
        }

        $Filters = Get-CimInstance -Namespace $Ns -ClassName __EventFilter |
            Select-Object Name, Query, QueryLanguage, EventNamespace, @{
                Name = "CreatorSID"
                Expression = $Sid
            }

        $Consumers = Get-CimInstance -Namespace $Ns -ClassName __EventConsumer |
            Select-Object @{
                Name = "ConsumerType"
                Expression = { $_.CimClass.CimClassName }
            }, Name, CommandLineTemplate, ExecutablePath, WorkingDirectory, ScriptingEngine, `
            ScriptFileName, ScriptText, Filename, Text, SourceName, @{
                Name = "CreatorSID"
                Expression = $Sid
            }

        $Bindings = Get-CimInstance -Namespace $Ns -ClassName __FilterToConsumerBinding |
            Select-Object @{
                Name = "Filter"
                Expression = { $_.Filter.Name }
            }, @{
                Name = "Consumer"
                Expression = { $_.Consumer.Name }
            }, @{
                Name = "ConsumerClass"
                Expression = { $_.Consumer.CimClass.CimClassName }
            }

        Write-OutputToCsv -Data $Filters -OutputFile $OutputFiles[0]
        Write-OutputToCsv -Data $Consumers -OutputFile $OutputFiles[1]
        Write-OutputToCsv -Data $Bindings -OutputFile $OutputFiles[2]
    }


    # 05.40
    function Get-ImageFileExecutionOptions {
        param([string]$OutputFile)

        $Roots = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options",
                "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit"
        $Data = foreach ($Root in $Roots) {
            if (-not (Test-Path -LiteralPath $Root)) {
                continue
            }
            foreach ($Key in Get-ChildItem -LiteralPath $Root ) {
                $Props = Get-ItemProperty -LiteralPath $Key.PSPath
                foreach ($P in ($Props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" })) {
                    [PSCustomObject]@{
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


    # 05.41
    function Get-StartupFolderItems {
        param([string]$OutputFile)

        $Folders = @([PSCustomObject]@{
            User = "ALL USERS"
            Path = Join-Path -Path $env:ProgramData -ChildPath "Microsoft\Windows\Start Menu\Programs\StartUp"
        })
        foreach ($H in ($global:TriageUserHives | Where-Object ProfilePath)) {
            $Folders += [PSCustomObject]@{
                User = $H.UserName
                Path = Join-Path -Path $H.ProfilePath `
                    -ChildPath "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
            }
        }
        $Data = foreach ($F in $Folders) {
            if (-not (Test-Path -LiteralPath $F.Path)) {
                continue
            }
            Get-ChildItem -LiteralPath $F.Path -Recurse -Force -File | ForEach-Object {
                [PSCustomObject]@{
                    User        = $F.User
                    FullName    = $_.FullName
                    Length      = $_.Length
                    CreatedUtc  = $_.CreationTimeUtc.ToString("o")
                    ModifiedUtc = $_.LastWriteTimeUtc.ToString("o")
                    SHA256      = try {
                        (Get-StreamHash -LiteralPath $_.FullName -IncludeMd5:$false).SHA256
                    }
                    catch {
                        $null
                    }
                }
            }
        }
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # 05.42
    function Get-BitsJobs {
        <#
        .SYNOPSIS
            Querying BITS can start the service, which would change the target.
            Only query it if it is already running.
        #>
        param([string]$OutputFile)

        $Svc = Get-Service -Name BITS
        if (-not $Svc -or $Svc.Status -ne "Running") {
            Write-OutputToCsv -Data ([PSCustomObject]@{
                Note = (
                    "BITS service was not running; jobs not queried. See the BITS " +
                    "database copy in 011_Raw_Artifacts."
                )
            }) -OutputFile $OutputFile
            return
        }
        $Data = Get-BitsTransfer -AllUsers -ErrorAction Stop |
            Select-Object -Property *, @{
                Name = "Files"
                Expression = {
                    @($_.FileList |
                    ForEach-Object {
                        "$( $_.RemoteName ) -> $( $_.LocalName )"
                    }) -join "; "
                }
            } -ExcludeProperty FileList
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # 05.43
    function Get-DownloadedExecutables {
        param([string]$OutputFile)

        $ExecutableFileTypes = @(Get-TriageConfig -Key "ExecutableFileTypes")

        $Data = foreach ($Root in (Get-TriageScanRoots)) {
            Get-ChildItem -LiteralPath $Root -Recurse -Force -File -Include $ExecutableFileTypes `
                -ErrorAction SilentlyContinue |
                ForEach-Object {
                    $Ads = Get-Item -LiteralPath $_.FullName -Stream Zone.Identifier `
                        -ErrorAction SilentlyContinue
                    if ($Ads) {
                        [PSCustomObject]@{
                            FileName      = $_.FullName
                            Stream        = $Ads.Stream
                            LastWriteTime = $_.LastWriteTime
                        }
                    }
                }
        }
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 05.44
    function Get-OpenFilesList {
        param([string]$OutputFile)

        $Data = & (Get-TriageBinary "openfiles") /query /FO CSV
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $Tasks = @(
        @{
            Action  = { param($Paths) Get-PnPSignedDrivers -OutputFile $Paths[0] }
            Message = "05.01_Gathering Driver Info for PnP Devices..."
            Files   = "05.01_pnp_signed_drivers.csv"
        }
        @{
            Action  = { param($Paths) Get-OpenShares -OutputFile $Paths[0] }
            Message = "05.02_Getting Open Shares..."
            Files   = "05.02_open_shares.txt"
        }
        @{
            Action  = { param($Paths) Get-LogicalDisks -OutputFile $Paths[0] }
            Message = "05.03_Getting Logical Drives..."
            Files   = "05.03_logical_disks.csv"
        }
        @{
            Action  = { param($Paths) Get-MappedLogicalDisks -OutputFile $Paths[0] }
            Message = "05.04_Getting Mapped Logical Disks..."
            Files   = "05.04_logical_disks_mapped.txt"
        }
        @{
            Action  = { param($Paths) Get-ScheduledJobs -OutputFile $Paths[0] }
            Message = "05.05_Listing Scheduled Jobs..."
            Files   = "05.05_scheduled_jobs.txt"
        }
        @{
            Action  = { param($Paths) Get-ScheduledTasks -OutputFile $Paths }
            Message = "05.06_Getting Scheduled Tasks and Task Info..."
            Files   = "05.06a_scheduled_task_events.txt",
                      "05_06b_scheduled_task_info.txt"
        }
        @{
            Action  = { param($Paths) Get-HotFixes -OutputFile $Paths[0] }
            Message = "05.07_Listing Applied HotFixes..."
            Files   = "05.07_hot_fixes.csv"
        }
        @{
            Action  = { param($Paths) Get-InstalledApps -OutputFile $Paths[0] }
            Message = "05.08_Getting Installed Applications..."
            Files   = "05.08_installed_apps.csv"
        }
        @{
            Action  = { param($Paths) Get-AppxPackages -OutputFile $Paths[0] }
            Message = "05.09_Getting AppX packages..."
            Files   = "05.09_appx_packages.csv"
        }
        @{
            Action  = { param($Paths) Get-VolumeShadowCopies -OutputFile $Paths[0] }
            Message = "05.10_Listing Volume Shadow Copies..."
            Files   = "05.10_volume_shadow_copies.csv"
        }
        @{
            Action  = { param($Paths) Get-AppInitDllKey -OutputFile $Paths[0] }
            Message = "05.11_Getting AppInit_DLL Registry Keys..."
            Files   = "05.11_appinit_dll_key.txt"
        }
        @{
            Action  = { param($Paths) Get-UacGroupPolicy -OutputFile $Paths[0] }
            Message = "05.12_Listing UAC Group Policy Settings..."
            Files   = "05.12_uac_group_policy.txt"
        }
        @{
            Action  = { param($Paths) Get-ActiveSetupInstalls -OutputFile $Paths[0] }
            Message = "05.13_Getting Active Setup Installs..."
            Files   = "05.13_active_setup_installs.txt"
        }
        @{
            Action  = { param($Paths) Get-AppPathRegKeys -OutputFile $Paths[0] }
            Message = "05.14_Getting App Path Registry Keys..."
            Files   = "05.14_app_path_reg_keys.txt"
        }
        @{
            Action  = { param($Paths) Get-DllsLoadedByExplorerShell -OutputFile $Paths[0] }
            Message = "05.15_Listing .dll Files Loaded by Explorer.exe Shell..."
            Files   = "05.15_dlls_loaded_by_explorer_shell.txt"
        }
        @{
            Action  = { param($Paths) Get-ShellAndUserInitValues -OutputFile $Paths[0] }
            Message = "05.16_Getting Shell and UserInit Values..."
            Files   = "05.16_shell_and_user_init_values.txt"
        }
        @{
            Action  = { param($Paths) Get-SvcValues -OutputFile $Paths[0] }
            Message = "05.17_Listing Security Center SVC Values..."
            Files   = "05.17_svc_values.txt"
        }
        @{
            Action  = { param($Paths) Get-DesktopAddressBar -OutputFile $Paths[0] }
            Message = "05.18_Parsing Desktop Address Bar History..."
            Files   = "05.18_desktop_address_bar.csv"
        }
        @{
            Action  = { param($Paths) Get-RunMruKeyInfo -OutputFile $Paths[0] }
            Message = "05.19_Getting RunMRU key Information..."
            Files   = "05.19_run_mru_key_info.csv"
        }
        @{
            Action  = { param($Paths) Get-StartMenuData -OutputFile $Paths[0] }
            Message = "05.20_Listing Start Menu Data..."
            Files   = "05.20_start_menu_data.txt"
        }
        @{
            Action  = { param($Paths) Get-ProgExeBySessionManager -OutputFile $Paths[0] }
            Message = "05.21_Listing Programs Executed by Session Manager..."
            Files   = "05.21_prog_exe_by_session_manager.txt"
        }
        @{
            Action  = { param($Paths) Get-ShellFolderInfo -OutputFile $Paths[0] }
            Message = "05.22_Getting User Startup Shell Folder Information..."
            Files   = "05.22_shell_folders.txt"
        }
        @{
            Action  = { param($Paths) Get-ApprovedShellExts -OutputFile $Paths[0] }
            Message = "05.23_Listing Approved Shell Extensions..."
            Files   = "05.23_approved_shell_exts.txt"
        }
        @{
            Action  = { param($Paths) Get-AppCertDlls -OutputFile $Paths[0] }
            Message = "05.24_Listing AppCert .dll Files..."
            Files   = "05.24_app_cert_dlls.txt"
        }
        @{
            Action  = { param($Paths) Get-ExeFileShellCommands -OutputFile $Paths[0] }
            Message = "05.25_Listing .exe File Shell Command Configuration..."
            Files   = "05.25_exe_file_shell_commands.txt"
        }
        @{
            Action  = { param($Paths) Get-ShellCommands -OutputFile $Paths[0] }
            Message = "05.26_Listing Shell Commands..."
            Files   = "05.26_shell_commands.txt"
        }
        @{
            Action  = { param($Paths) Get-BcdRelatedData -OutputFile $Paths[0] }
            Message = "05.27_Getting BCD Related Data..."
            Files   = "05.27_bcd_related_data.txt"
        }
        @{
            Action  = { param($Paths) Get-LoadedLsaPackages -OutputFile $Paths[0] }
            Message = "05.28_Reading Loaded LSA Packages Data..."
            Files   = "05.28_loaded_lsa_packages.txt"
        }
        @{
            Action  = { param($Paths) Get-BrowserHelperObjects -OutputFile $Paths[0] }
            Message = "05.29_Parsing Browser Helper Objects..."
            Files   = "05.29_browser_helper_objects.txt"
        }
        @{
            Action  = { param($Paths) Get-BrowserHelperObjectsX64 -OutputFile $Paths[0] }
            Message = "05.30_Parsing Browser Helper Objects (64 Bit)..."
            Files   = "05.30_browser_helper_objects_x64.txt"
        }
        @{
            Action  = { param($Paths) Get-UsbDevices -OutputFiles $Paths }
            Message = "05.31_Listing Connected USB Devices..."
            Files   = "05.31a_usb_devices_from_Enum-USB.csv",
                      "05.31b_usb_devices_from_Control-USBSTOR.csv"
        }
        @{
            Action  = { param($Paths) Get-PnpDevices -OutputFile $Paths[0] }
            Message = "05.32_Listing Connected PnP Devices..."
            Files   = "05.32_pnp_devices.csv"
        }
        @{
            Action  = { param($Paths) Copy-HostFile -OutputFile $Paths[0] }
            Message = "05.33_Copying *hosts* File..."
            Files   = "05.33_hosts_file.txt"
        }
        @{
            Action  = { param($Paths) Copy-ServicesFile -OutputFile $Paths[0] }
            Message = "05.34_Copying *services* File..."
            Files   = "05.34_services_file.txt"
        }
        @{
            Action  = { param($Paths) Get-AuditPolicy -OutputFile $Paths[0] }
            Message = "05.35_Listing Computer Audit Policy..."
            Files   = "05.35_audit_policy.txt"
        }
        @{
            Action  = { param($Paths) Get-NonValidExes -OutputFile $Paths[0] }
            Message = "05.36_Listing Exes Without Valid Authenticode Signature..."
            Files   = "05.36_non_valid_exe_files.txt"
        }
        @{
            Action  = { param($Paths) Get-OptionalFeatures -OutputFile $Paths[0] }
            Message = "05.37_Gathering Optional Features..."
            Files   = "05.37_optional_features.csv"
        }
        @{
            Action  = { param($Paths) Get-ServicingPackages -OutputFile $Paths[0] }
            Message = "05.38_Gathering Service Packages..."
            Files   = "05.38_servicing_packages.csv"
        }
        @{
            Action  = { param($Paths) Get-WmiEventSubscriptions -OutputFiles $Paths }
            Message = "05.39_Getting WMI event subscriptions..."
            Files   = "05.39a_wmi_event_filters.csv",
                      "05.39b_wmi_event_consumers.csv",
                      "05.39c_wmi_filter_consumer_bindings.csv"
        }
        @{
            Action  = { param($Paths) Get-ImageFileExecutionOptions -OutputFile $Paths[0] }
            Message = "05.40_Getting Image File Execution Options..."
            Files   = "05.40_image_file_execution_options.csv"
        }
        @{
            Action  = { param($Paths) Get-StartupFolderItems -OutputFile $Paths[0] }
            Message = "05.41_Getting startup folder contents..."
            Files   = "05.41_startup_folder_items.csv"
        }
        @{
            Action  = { param($Paths) Get-BitsJobs -OutputFile $Paths[0] }
            Message = "05.42_Getting BITS jobs..."
            Files   = "05.43_bits_jobs.csv"
        }
        @{
            Action  = { param($Paths) Get-DownloadedExecutables -OutputFile $Paths[0] }
            Message = "05.43_Getting downloaded executables..."
            Files   = "05.43_downloaded_executables.txt"
        }
		@{
            Action  = { param($Paths) Get-OpenFilesList -OutputFile $Paths[0] }
            Message = "05.44_Processing List of Open Files..."
            Files   = "05.44_list_of_open_files.txt"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $SystemFolder

}
