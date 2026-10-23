#testing.ps1


# Relative to the toolkit root. The loader turns these into full paths.
$Binaries = @{
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


function Get-WhoAmI {
    param(
        [string]$TxtFile = (Join-Path -Path $PSScriptRoot -ChildPath "who_am_I.txt")
    )
    $ExePath = $Binaries["whoami"]

    if (-not $ExePath) {
        throw "No executable found for key [ whoami ]"
    }
    $Data = & $Binaries["whoami"] /ALL /FO LIST
    $Data | Out-File -FilePath $TxtFile -NoClobber
}