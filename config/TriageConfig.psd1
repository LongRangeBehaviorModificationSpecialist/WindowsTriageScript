@{
    SchemaVersion = 1

    Branding = @{
        ToolName = "NOVA ICAC VECTOR Triage Application"
        Author   = "SA Michael Sponheimer"
        DLU      = "06-Nov-2026"
    }


    Modules = @(
        "001_Device",
        "002_Users",
        "003_Network",
        "004_Processes",
        "005_System",
        "006_Prefetch",
        "007_Event_Logs",
        "008_Firewall",
        "009_Encryption",
        "010_Internet",
        "011_Raw_Artifacts"
    )


    # Relative to the toolkit root. The loader turns these into full paths.
    Binaries = @{
        auditpol             = "bin\auditpol.exe"
        driverquery          = "bin\driverquery.exe"
        EDD                  = "bin\EDDv310.exe"
        ipconfig             = "bin\ipconfig.exe"
        MagnetProcessCapture = "bin\MagnetProcessCapture.exe"
        MagnetRamCapture     = "bin\MagnetRAMCapture.exe"
        net                  = "bin\net.exe"
        netsh                = "bin\netsh.exe"
        netstat              = "bin\NETSTAT.EXE"
        openfiles            = "bin\openfiles.exe"
        PSInfo               = "bin\PsInfo.exe"
        qwinsta              = "bin\qwinsta.exe"
        RawCopy              = "bin\RawCopy.exe"
        reg                  = "bin\reg.exe"
        robocopy             = "bin\Robocopy.exe"
        SQLite3              = "bin\sqlite3.exe"
        systeminfo           = "bin\systeminfo.exe"
        wevtutil             = "bin\wevtutil.exe"
        whoami               = "bin\whoami.exe"
    }


    Defaults = @{
        ScratchFolder         = "_scratch"
        HashIncludeMd5        = $true
        ArchiveExcludeFolders = @("Ram_Capture", "011_Raw_Artifacts\NTFS")
        TimestampFormat       = "yyyy-MM-ddTHH:mm:ss.fffZ"
    }


    RawArtifacts = @{
        Enabled = @(
            "SystemHives", "Amcache", "UserHives", "Prefetch", "Srum",
            "LnkAndJumpLists", "BrowserDatabases", "StartupFolders",
            "WmiRepository", "Bits", "WindowsUpdate", "Defender", "Mft",
            "UsnJrnl", "ScheduledTasks", "SetupApi", "WerReports",
            "RecycleBin", "UserArtifacts"
        )
        LargeSets             = @("Mft", "UsnJrnl")
        MinFreeGbForLargeSets = 10
    }


    UserArtifacts = @(
        @{
            Name = "ActivitiesCache"
            Path = "AppData\Local\ConnectedDevicesPlatform"
            Filter = "ActivitiesCache.db*"
        }
        @{
            Name = "Thumbcache"
            Path = "AppData\Local\Microsoft\Windows\Explorer"
            Filter = "thumbcache_*.db"
        }
        @{
            Name = "IconCache"
            Path = "AppData\Local\Microsoft\Windows\Explorer"
            Filter = "iconcache_*.db"
        }
        @{
            Name = "Notifications"
            Path = "AppData\Local\Microsoft\Windows\Notifications"
            Filter = "wpndatabase.db*"
        }
        @{
            Name = "RdpBitmapCache"
            Path = "AppData\Local\Microsoft\Terminal Server Client\Cache"
        }
        @{
            Name = "OneDriveLogs"
            Path = "AppData\Local\Microsoft\OneDrive\logs"
        }
        @{
            Name = "AnyDesk"
            Path = "AppData\Roaming\AnyDesk"
            Filter = "*.trace"
        }
    )


    ExecutableFileTypes = @(
        "*.BAT", "*.BIN", "*.CGI", "*.CMD", "*.COM", "*.DLL", "*.EXE",
        "*.JAR", "*.JOB", "*.JSE", "*.MSI", "*.PAF", "*.PS1", "*.SCR",
        "*.SCRIPT", "*.VB", "*.VBE", "*.VBS", "*.VBSCRIPT", "*.WS", "*.WSF"
    )


    ScanFolders = @{
        # Relative to each user's profile folder
        UserSubFolders = @(
            "Downloads",
            "Desktop",
            "Documents",
            "AppData\Local\Temp",
            "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
        )
        # Relative to the system drive root
        SharedFolders = @(
            "Temp",
            "Windows\Temp",
            "Users\Public",
            "ProgramData"
        )
        # Signature checks, NOT searched recursively
        SystemExeFolders = @(
            "Windows",
            "Windows\System32",
            "Windows\SysWOW64",
            "Windows\System32\wbem",
            "Windows\System32\WindowsPowerShell\v1.0"
        )
    }


    # An array, because hashtables in a .psd1 are unordered
    EventLogs = @(
        "Application",
        "Security",
        "System",
        "Windows PowerShell",
        "Microsoft-Windows-PowerShell/Operational",
        "Microsoft-Windows-PowerShell/Admin",
        "Microsoft-Windows-Application-Experience/Program-Inventory",
        "Microsoft-Windows-DriverFrameworks-UserMode/Operational",
        "Microsoft-Windows-Partition/Diagnostic",
        "Microsoft-Windows-Sysmon/Operational",
        "Microsoft-Windows-TaskScheduler/Operational",
        "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational",
        "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational",
        "Microsoft-Windows-TerminalServices-RDPClient/Operational",
        "Microsoft-Windows-Windows Defender/Operational",
        "Microsoft-Windows-Windows Defender/WHC",
        "Microsoft-Windows-WMI-Activity/Operational",
        "Microsoft-Windows-Bits-Client/Operational",
        "Microsoft-Windows-WinRM/Operational",
        "Microsoft-Windows-CodeIntegrity/Operational",
        "Microsoft-Windows-Windows Firewall With Advanced Security/Firewall",
        "Microsoft-Windows-NetworkProfile/Operational",
        "Microsoft-Windows-WLAN-AutoConfig/Operational",
        "Microsoft-Windows-SmbClient/Security",
        "Microsoft-Windows-AppLocker/EXE and DLL",
        "Microsoft-Windows-VHDMP/Operational",
        "Microsoft-Windows-TerminalServices-RdpCoreTS/Operational",
        "OAlerts"
    )


    Browsers = @(
        @{
            Name = "Chrome"
            Type = "Chromium"
            Root = "AppData\Local\Google\Chrome\User Data"
        }
        @{
            Name = "Edge"
            Type = "Chromium"
            Root = "AppData\Local\Microsoft\Edge\User Data"
        }
        @{
            Name = "Brave"
            Type = "Chromium"
            Root = "AppData\Local\BraveSoftware\Brave-Browser\User Data"
        }
        @{
            Name = "Firefox"
            Type = "Firefox"
            Root = "AppData\Roaming\Mozilla\Firefox\Profiles"
        }
        @{
            Name = "Vivaldi"
            Type = "Chromium"
            Root = "AppData\Local\Vivaldi\User Data"
        }
        @{
            Name = "Opera"
            Type = "Chromium"
            Root = "AppData\Roaming\Opera Software\Opera Stable"
            Direct = $true
        }
        @{
            Name = "OperaGX"
            Type = "Chromium"
            Root = "AppData\Roaming\Opera Software\Opera GX Stable"
            Direct = $true
        }
    )

}
