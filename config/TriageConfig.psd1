@{
    SchemaVersion = 1

    Branding = @{
        ToolName    = "NOVA ICAC VECTOR Triage Application"
        Author      = "Michael Sponheimer"
        LastUpdated = "06-Oct-2026"
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
        "010_Internet"
    )

    # Relative to the toolkit root. The loader turns these into full paths.
    Binaries = @{
        EDD                  = "bin\EDDv310.exe"
        ipconfig             = "bin\ipconfig.exe"
        MagnetProcessCapture = "bin\MagnetProcessCapture.exe"
        MagnetRamCapture     = "bin\MagnetRAMCapture.exe"
        netstat              = "bin\NETSTAT.EXE"
        PSInfo               = "bin\PsInfo.exe"
        SQLite3              = "bin\sqlite3.exe"
        systeminfo           = "bin\systeminfo.exe"
        whoami               = "bin\whoami.exe"
        net                  = "bin\net.exe"
        netsh                = "bin\netsh.exe"
        auditpol             = "bin\auditpol.exe"
        driverquery          = "bin\driverquery.exe"
        openfiles            = "bin\openfiles.exe"
        reg                  = "bin\reg.exe"
    }

    Defaults = @{
        ScratchFolder         = "_scratch"
        HashIncludeMd5        = $true
        ArchiveExcludeFolders = @("Ram_Capture")
        TimestampFormat       = "yyyy-MM-ddTHH:mm:ss.fffZ"
    }

    ExecutableFileTypes = @(
        "*.BAT", "*.BIN", "*.CGI", "*.CMD", "*.COM", "*.DLL", "*.EXE",
        "*.JAR", "*.JOB", "*.JSE", "*.MSI", "*.PAF", "*.PS1", "*.SCR",
        "*.SCRIPT", "*.VB", "*.VBE", "*.VBS", "*.VBSCRIPT", "*.WS", "*.WSF"
    )

    # An array, because hashtables in a .psd1 are unordered
    EventLogs = @(
        @{
            Log  = "Application"
            File = "application_log.csv"
        }
        @{
            Log  = "Security"
            File = "security_log.csv"
        }
        @{
            Log  = "System"
            File = "system_log.csv"
        }
        @{
            Log  = "Microsoft-Windows-PowerShell/Operational"
            File = "win_powershell_operational_log.csv"
        }
        @{
            Log  = "Microsoft-Windows-Application-Experience/Program-Inventory"
            File = "win_application_experience_program_inventory_log.csv"
        }
        @{
            Log  = "Microsoft-Windows-DriverFrameworks-UserMode/Operational"
            File = "win_driveframeworks_usermode_operational_log.csv"
        }
        @{
            Log  = "Microsoft-Windows-Partition/Diagnostic"
            File = "win_partition_diagnostic_log.csv"
        }
        @{
            Log  = "Microsoft-Windows-PowerShell/Admin"
            File = "win_powershell_admin_log.csv"
        }
        @{
            Log  = "Microsoft-Windows-Sysmon/Operational"
            File = "win_sysmon_operational_log.csv"
        }
        @{
            Log  = "Microsoft-Windows-TaskScheduler/Operational"
            File = "win_taskscheduler_operational_log.csv"
        }
        @{
            Log  = "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational"
            File = "windows_terminalservices_localsessionmanager_operational_log.csv"
        }
        @{
            Log  = "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational"
            File = "win_terminalservices_remoteconnectionmanager_operational_log.csv"
        }
        @{
            Log  = "Microsoft-Windows-TerminalServices-RDPClient/Operational"
            File = "win_terminalservices_rdpclient_operational_log.csv"
        }
        @{
            Log  = "Microsoft-Windows-Windows Defender/Operational"
            File = "win_windows_defender_operational_log.csv"
        }
        @{
            Log  = "Microsoft-Windows-Windows Defender/WHC"
            File = "win_windows_defender_whc_log.csv"
        }
        @{
            Log  = "Windows PowerShell"
            File = "win_powershell_log.csv"
        }
    )

    Browsers = @(
        @{ Name = "Chrome";  Type = "Chromium"; Root = "AppData\Local\Google\Chrome\User Data" }
        @{ Name = "Edge";    Type = "Chromium"; Root = "AppData\Local\Microsoft\Edge\User Data" }
        @{ Name = "Brave";   Type = "Chromium"; Root = "AppData\Local\BraveSoftware\Brave-Browser\User Data" }
        @{ Name = "Firefox"; Type = "Firefox";  Root = "AppData\Roaming\Mozilla\Firefox\Profiles" }
        @{ Name = "Vivaldi"; Type = "Chromium"; Root = "AppData\Local\Vivaldi\User Data" }
    )
}
