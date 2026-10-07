@{
    SchemaVersion = 1

    Branding = @{
        ToolName    = "NOVA ICAC VECTOR Triage Application"
        Author      = "Michael Sponheimer"
        LastUpdated = "07-Oct-2026"
    }

    Modules = @(
        "001_Device",
        "002_Users",
        "003_Network",
        "004_Process",
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
        robocopy             = "bin\Robocopy.eve"
        SQLite3              = "bin\sqlite3.exe"
        systeminfo           = "bin\systeminfo.exe"
        wevtutil             = "bin\wevtutil.exe"
        whoami               = "bin\whoami.exe"
    }

    Defaults = @{
        ScratchFolder         = "_scratch"
        HashIncludeMd5        = $true
        ArchiveExcludeFolders = @("Ram_Capture", "011_Raw_Atrifacts\NTFS")
        TimestampFormat       = "yyyy-MM-ddTHH:mm:ss.fffZ"
    }

    RawArtifacts = @{
        Enabled = @(
            "SystemHives", "Amcache", "UserHives", "Prefetch", "Srum", "LnkAndJumpLists", "BrowserDatabases",
            "StartupFolders", "WmiRepository", "Bits", "WindowsUpdate", "Defender", "Mft", "UsnJrnl"
        )
        LargeSets             = @("Mft", "UsnJrnl")
        MinFreeGbForLargeSets = 10
    }

    ExecutableFileTypes = @(
        "*.BAT", "*.BIN", "*.CGI", "*.CMD", "*.COM", "*.DLL", "*.EXE",
        "*.JAR", "*.JOB", "*.JSE", "*.MSI", "*.PAF", "*.PS1", "*.SCR",
        "*.SCRIPT", "*.VB", "*.VBE", "*.VBS", "*.VBSCRIPT", "*.WS", "*.WSF"
    )

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
        "Microsoft-Windows-Windows Firewall With Advanced Security/Firewall"
    )

    Browsers = @(
        @{
            Name = "Chrome"
            Type = "Chromium"
            Root = "AppData\Local\Google\Chrome\User Data"
        }
        @{
            Name = "Edge"
            Type = "Chromium";
            Root = "AppData\Local\Microsoft\Edge\User Data"
        }
        @{
            Name = "Brave";
            Type = "Chromium";
            Root = "AppData\Local\BraveSoftware\Brave-Browser\User Data"
        }
        @{
            Name = "Firefox";
            Type = "Firefox";
            Root = "AppData\Roaming\Mozilla\Firefox\Profiles"
        }
        @{
            Name = "Vivaldi";
            Type = "Chromium";
            Root = "AppData\Local\Vivaldi\User Data"
        }
    )
}
