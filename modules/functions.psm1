# functions.psm1

# # List of file types to use in some commands
# $global:ExecutableFileTypes = @(
#     "*.BAT", "*.BIN", "*.CGI", "*.CMD", "*.COM", "*.DLL", "*.EXE",
#     "*.JAR", "*.JOB", "*.JSE", "*.MSI", "*.PAF", "*.PS1", "*.SCR",
#     "*.SCRIPT", "*.VB", "*.VBE", "*.VBS", "*.VBSCRIPT", "*.WS", "*.WSF"
# )

$Dlu = "05-Oct-2026"

if (-not $global:ToolkitRoot) {
    $global:ToolkitRoot = Split-Path -Path $PSScriptRoot -Parent
}

$global:Binaries = @{
    "EDD"                  = Join-Path -Path $global:ToolkitRoot -ChildPath "bin\EDDv310.exe"
    "ipconfig"             = Join-Path -Path $global:ToolkitRoot -ChildPath "bin\ipconfig.exe"
    "MagnetProcessCapture" = Join-Path -Path $global:ToolkitRoot -ChildPath "bin\MagnetProcessCapture.exe"
    "MagnetRamCapture"     = Join-Path -Path $global:ToolkitRoot -ChildPath "bin\MagnetRAMCapture.exe"
    "netstat"              = Join-Path -Path $global:ToolkitRoot -ChildPath "bin\NETSTAT.EXE"
    "PSInfo"               = Join-Path -Path $global:ToolkitRoot -ChildPath "bin\PsInfo.exe"
    "SQLite3"              = Join-Path -Path $global:ToolkitRoot -ChildPath "bin\sqlite3.exe"
    "systeminfo"           = Join-Path -Path $global:ToolkitRoot -ChildPath "bin\systeminfo.exe"
    "whoami"               = Join-Path -Path $global:ToolkitRoot -ChildPath "bin\whoami.exe"
    "net"                  = Join-Path -Path $global:ToolkitRoot -ChildPath "bin\net.exe"
    "netsh"                = Join-Path -Path $global:ToolkitRoot -ChildPath "bin\netsh.exe"
    "auditpol"             = Join-Path -Path $global:ToolkitRoot -ChildPath "bin\auditpol.exe"
    "driverquery"          = Join-Path -Path $global:ToolkitRoot -ChildPath "bin\driverquery.exe"
    "openfiles"            = Join-Path -Path $global:ToolkitRoot -ChildPath "bin\openfiles.exe"
    "reg"                  = Join-path -Path $global:ToolkitRoot -ChildPath "bin\reg.exe"

}

function Get-InitialSetup {
    param(
        [string]$OutputRoot
    )

    if (-not $OutputRoot) {
        $OutputRoot = $global:ToolkitRoot
    }
    if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
        throw "Output folder does not exist: $OutputRoot"
    }

    $RunDate = Get-Date -Format yyyyMMdd_HHmmss

    $Idx  = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1).InterfaceIndex

    $Ipv4 = if ($Idx) { (Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $Idx -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress }
    if (-not $Ipv4) {
        $Ipv4 = "NoIPv4"
    }

    $MergedName           = "{0}_{1}_{2}" -f $RunDate, $Ipv4, $env:COMPUTERNAME
    $global:ResultsFolder = Join-Path -Path $OutputRoot -ChildPath $MergedName
    $null = New-Item -ItemType Directory -Path $global:ResultsFolder -Force

    $LogFolder      = Join-Path -Path $global:ResultsFolder -ChildPath "Logs"
    $null           = New-Item -ItemType Directory -Path $LogFolder -Force

    $global:LogFile = Join-Path -Path $LogFolder -ChildPath "$( $MergedName )_Script.log"
    $null           = New-Item -ItemType File -Path $global:LogFile -Force
}

# function Invoke-TriageTranscript {

#     try {
#         # Start transcript to record all of the screen output
#         $Transcript_beginMsg = "Powershell Transcript started..."
#         Start-Transcript -OutputDirectory $LogFolder -IncludeInvocationHeader -NoClobber
#         Show-Message -Message $Transcript_beginMsg -Level INFO -AddToLog
#     }
#     catch {
#         $ErrorMsg = "Failed to start Powershell Transcript: $( $_.Exception.Message )"
#         Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
#     }
# }

function Write-OutputToCsv {
    param(
        [Parameter(Mandatory)][AllowNull()][AllowEmptyCollection()][object]$Data,
        [Parameter(Mandatory = $true)][string]$OutputFile
    )

    process {
        if ($null -eq $Data -or @($Data).Count -eq 0) {
            "No data was found when running this function." | Out-File -FilePath $OutputFile -Encoding UTF8
        }
        else {
            $Data | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
        }
    }
}

function Show-IsAdmin {

    try {
        $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($IsAdmin) {
            Show-Message -Message "DFIR Session starting as Administrator..." -Level INFO -AddToLog -MessageColor Green
        }
        else {
            Show-Message -Message "No Administrator session detected. For the best performance run as Administrator. Not all items can be collected. DFIR Session starting..." -Level WARNING -AddToLog
        }
    }
    catch {
        $ErrorMsg = "Execution failed during $( $MyInvocation.MyCommand.Name ).  Error => $( $_.Exception.Message )"
        Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
    }
}

function Show-Message {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO","WARNING","ERROR","SUCCESS")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [string]$File,

        [Parameter(Mandatory = $false)]
        [string]$ExecutionTime,

        # Override colors if desired
        [Parameter(Mandatory = $false)]
        [System.ConsoleColor]$TimestampColor = "Cyan",

        [Parameter(Mandatory = $false)]
        [System.ConsoleColor]$MessageColor = "Gray",

        [switch]$NoTime,

        [switch]$AddToLog,

        [switch]$SpaceAbove
    )

    try {
        switch ($Level) {
            "ERROR"   { $global:TriageErrorCount++ }
            "WARNING" { $global:TriageWarningCount++ }
        }

        # Handle SUCCESS auto-message
        if ($Level -eq "SUCCESS" -and $File) {
            $Message = "Process completed. Output saved to [$( [System.IO.Path]::GetFileName($File) )]"
            if ($ExecutionTime) {
                $Message += " (completed in $ExecutionTime)."
            }
        }

        # Build timestamp string only (no color attached yet)
        if ($NoTime) {
            $Timestamp = ""
        }
        else {
            $Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }

        # Build the log entry (for file logging - plain text only)
        $LogEntryPrefix = "[$Timestamp] [$Level]"
        $LogMessage = "$LogEntryPrefix $Message"

        # Determine display color based on Level
        switch ($Level) {
            "SUCCESS" { $DisplayColor = "Green" }
            "WARNING" { $DisplayColor = "Yellow" }
            "ERROR"   { $DisplayColor = "Red" }
            default   { $DisplayColor = $MessageColor }
        }

        # OUTPUT TO TERMINAL - colors are applied here
        if ($NoTime) {
            Write-Host $Message -ForegroundColor $DisplayColor
        }
        elseif ($SpaceAbove) {
            Write-Host "`n[ $Timestamp ] " -ForegroundColor $TimestampColor -NoNewLine
            Write-Host $Message -ForegroundColor $DisplayColor
        }
        else {
            Write-Host "[ $Timestamp ] " -ForegroundColor $TimestampColor -NoNewLine
            Write-Host $Message -ForegroundColor $DisplayColor
        }

        # LOG TO FILE (if requested)
        if ($AddToLog -and $LogFile) {
            try {
                $LogMessage | Out-File -FilePath $LogFile -Append -Encoding UTF8 -NoClobber
            }
            catch {
                # If writing to the USB log fails, tell the examiner
                Write-Host "CRITICAL: Unable to write to triage log file! Error => $( $_.Exception.Message )" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Error "An uncaught error occured. Error => $( $_.Exception.Message )"
    }
}

function Write-LogMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message
    )

    process {
        if (-not $Message) {
            Write-Error -Message "The '-Message' parameter cannot be empty."
            return
        }

        $Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        " [$Timestamp ] $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    }
}

function Write-OutputToFile {
    # Writes the results of the commands to the $OutputFile

    param(
        # [Parameter(Mandatory = $false)]
        [string]$Command,
        # [Parameter(Mandatory = $false)]
        [System.Object]$Data,
        [Parameter(Mandatory)][string]$OutputFile,
        [switch]$Append
    )

    $Header = if ($Command) {
        "Command: $Command`r`n`r`n"
    }
    else {
        ""
    }
    $Body   = if ($Data) {
        $Data | Out-String -Width 4096
    }
    else {
        "No data was found when running this function.`r`n"
    }

    if ($Append) {
        ($Header + $Body) | Out-File -FilePath $OutputFile -Encoding UTF8 -Append
    }
    else{
        ($Header + $Body) | Out-File -FilePath $OutputFile -Encoding UTF8
    }
}

function Read-LogHost {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Prompt,

        [ConsoleColor]$TimeStampColor = "Cyan",
        [ConsoleColor]$PromptColor = "Gray",

        # Pass through standard Read-Host parameters
        [switch]$AsSecureString
    )

    $Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

    Write-Host "[$Timestamp] " -ForegroundColor $TimeStampColor -NoNewline
    Write-Host $Prompt -ForegroundColor $PromptColor -NoNewline

    if ($AsSecureString) {
        Read-Host -AsSecureString
    } else {
        Read-Host
    }
}

function Test-IfExists {
    param(
        [string]$FolderName,
        [string]$FileName,
        [ValidateSet("FOLDER","FILE")][string]$Type
    )

    if ($Type -eq "FOLDER") {
        $FolderNameText = $(Split-Path -Path $FolderName -Leaf)
        if (Test-Path $FolderName) {
            Show-Message -Message "[ $FolderNameText ] directory created successfully" -Level INFO -AddToLog -SpaceAbove -MessageColor Magenta
        }
        else {
            # Show-Message -Message "The necessary sub-directory does not exist `
            #     or could not be created => '$FolderNameText'" -Level ERROR -AddToLog
            return
        }
    }
    if ($Type -eq "FILE") {
        $FileNameText = $(Split-Path -Path $FileName -Leaf)
        if (Test-Path $FileName) {
            Show-Message -Message "[ $FileNameText ] file was created successfully." -Level INFO -AddToLog
        }
        else {
            # Show-Message -Message "There was an error creating the '$( $FileNameText )' file." -Level ERROR -AddToLog
            # return
            continue
        }
    }
}

function Get-PerUserRegistryValue {
    param(
        [Parameter(Mandatory)][string]$SubKey
    )

    foreach ($U in ($global:TriageUserHives | Where-Object Root)) {
        $Path = "$( $U.Root )\$SubKey"
        if (-not (Test-Path -LiteralPath $Path)) { continue }

        $Props = Get-ItemProperty -LiteralPath $Path
        foreach ($P in ($Props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" })) {
            [pscustomobject]@{
                UserName  = $U.UserName
                SID       = $U.Sid
                Key       = "HKU\<SID>\$SubKey"
                ValueName = $P.Name
                Data      = if ($P.Value -is [byte[]]) { ($P.Value | ForEach-Object { $_.ToString("x2") }) -join "" }
                            else { $P.Value -join "; " }
            }
        }
    }
}

function Get-PerUserRegistrySubKey {
    <#
    .SYNOPSIS
        Same idea as Get-PerUserRegistryValue, but lists the *subkeys*
        (MountPoints2, EscDomains)
    #>
    param(
        [Parameter(Mandatory)][string]$SubKey
    )

    foreach ($U in ($global:TriageUserHives | Where-Object Root)) {
        $Path = "$( $U.Root )\$SubKey"
        if (-not (Test-Path -LiteralPath $Path)) { continue }
        Get-ChildItem -LiteralPath $Path | ForEach-Object {
            [pscustomobject]@{
                UserName   = $U.UserName
                SID        = $U.Sid
                Key        = "HKU\<SID>\$SubKey"
                SubKeyName = $_.PSChildName
            }
        }
    }
}

function Export-PerUserRegistry {
    # One-stop wrapper: gather from every user hive and write a CSV
    param(
        [Parameter(Mandatory)][string[]]$SubKey,
        [Parameter(Mandatory)][string]$OutputFile,
        [switch]$EnumerateSubKeys
    )
    $Data = foreach ($Key in $SubKey) {
        if ($EnumerateSubKeys) {
            Get-PerUserRegistrySubKey -SubKey $Key
        }
        else {
            Get-PerUserRegistryValue  -SubKey $Key
        }
    }
    Write-OutputToCsv -Data $Data -OutputFile $OutputFile
}

function Mount-TriageUserHives {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$HiveFolder,
        [Parameter(Mandatory)][string]$ScratchFolder
    )

    Clear-TriageHives      # remove leftovers from any earlier run

    $null = New-Item -ItemType Directory -Path $HiveFolder, $ScratchFolder -Force
    $ProfileList = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'

    $Keys = Get-ChildItem -LiteralPath $ProfileList | Where-Object {
        $_.PSChildName -match '^S-1-(5-21|12-1)-' -and $_.PSChildName -notmatch '\.bak$'
    }

    foreach ($Key in $Keys) {
        $Sid = $Key.PSChildName
        $Out = [ordered]@{ UserName = $null; Sid = $Sid; ProfilePath = $null
                           Root = $null; MountName = $null; Note = '' }
        try {
            $ProfilePath = [Environment]::ExpandEnvironmentVariables(
                (Get-ItemProperty -LiteralPath $Key.PSPath -ErrorAction Stop).ProfileImagePath)
            $Out.ProfilePath = $ProfilePath
            try   { $Out.UserName = ([Security.Principal.SecurityIdentifier]$Sid).Translate([Security.Principal.NTAccount]).Value }
            catch { $Out.UserName = 'UNRESOLVED\' + (Split-Path $ProfilePath -Leaf) }

            $RawDir = Join-Path $HiveFolder $Sid
            $null   = New-Item -ItemType Directory -Path $RawDir -Force

            if (Test-Path -LiteralPath "Registry::HKEY_USERS\$Sid") {
                # Logged on: read the live hive and keep a snapshot
                $Out.Root = "Registry::HKEY_USERS\$Sid"
                & reg.exe save "HKU\$Sid" (Join-Path $RawDir 'NTUSER.DAT.regsave') /y 2>&1 | Out-Null
                $Out.Note = if ($LASTEXITCODE -eq 0) { 'live hive; snapshot via reg save' } else { 'live hive; reg save FAILED' }
            }
            else {
                $Src = Join-Path $ProfilePath 'NTUSER.DAT'
                if (-not (Test-Path -LiteralPath $Src)) {
                    $Out.Note = 'no NTUSER.DAT'
                }
                else {
                    # 1) Pristine copy and transaction logs go into the evidence folder
                    foreach ($F in 'NTUSER.DAT', 'NTUSER.DAT.LOG1', 'NTUSER.DAT.LOG2') {
                        $P = Join-Path $ProfilePath $F
                        if (Test-Path -LiteralPath $P) {
                            Copy-Item -LiteralPath $P -Destination $RawDir -Force -ErrorAction Stop
                        }
                    }

                    # 2) Load a disposable working copy (logs beside it so Windows replays them)
                    $Work = Join-Path $ScratchFolder "$Sid.DAT"
                    Copy-Item -LiteralPath (Join-Path $RawDir 'NTUSER.DAT') -Destination $Work -Force -ErrorAction Stop
                    foreach ($L in 'LOG1', 'LOG2') {
                        $LP = Join-Path $RawDir "NTUSER.DAT.$L"
                        if (Test-Path -LiteralPath $LP) {
                            Copy-Item -LiteralPath $LP -Destination "$Work.$L" -Force -ErrorAction Stop
                        }
                    }

                    $Mount  = "TRIAGE_$Sid"
                    $RegOut = & reg.exe load "HKU\$Mount" $Work 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $Out.Root = "Registry::HKEY_USERS\$Mount"; $Out.MountName = $Mount
                        $Out.Note = 'offline; loaded from working copy'
                    }
                    else {
                        $Out.Note = "reg load FAILED => $( $RegOut -join ' ' )"
                    }
                }
            }
        }
        catch {
            $Out.Root = $null      # collectors skip a hive with no Root
            $Out.Note = "FAILED => $( $_.Exception.Message )"
            Show-Message -Message "User hive for $Sid could not be prepared => $( $_.Exception.Message )" -Level ERROR -AddToLog
        }
        [pscustomobject]$Out
    }
}

function Dismount-TriageUserHives {
    # $Hives is kept so existing calls still work
    param(
        [object[]]$Hives,
    [string]$ScratchFolder
    )

    # Unloads this run's hives and anything a failed Mount left behind
    Clear-TriageHives

    if ($ScratchFolder -and (Test-Path -LiteralPath $ScratchFolder)) {
        Remove-Item -LiteralPath $ScratchFolder -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $ScratchFolder) {
            Show-Message -Message "Scratch folder could not be removed: $ScratchFolder" -Level WARNING -AddToLog
        }
    }
}

# function New-CaseManifest {
#     param(
#         [Parameter(Mandatory)][string]$CaseNumber,
#         [Parameter(Mandatory)][string]$Examiner,
#         [Parameter(Mandatory)][string]$Agency
#     )

#     return [ordered]@{
#         SchemaVersion       = "1.0"
#         CaseID              = $CaseNumber
#         Examiner            = $Examiner
#         Agency              = $Agency
#         ComputerName        = $env:COMPUTERNAME
#         OperatingSystem     = (Get-CimInstance Win32_OperatingSystem).Caption
#         AcquisitionStartUTC = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
#         ToolRuns            = [System.Collections.Generic.List[object]]::new()
#     }
# }

# function Complete-CaseManifest {
#     param(
#         [Parameter(Mandatory)][hashtable]$Manifest,
#         [Parameter(Mandatory)][string]$OutputDir
#     )

#     # Finalize metadata
#     $Manifest.AcquisitionEndUTC = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
#     $Manifest.DurationMinutes   = [math]::Round(
#         ((Get-Date) - [datetime]::Parse($Manifest.AcquisitionStartUTC)).TotalMinutes, 2
#     )

#     # Compute hashes for every artifact
#     $Manifest.Artifacts = Get-ChildItem -Path $OutputDir -File | ForEach-Object {
#         [ordered]@{
#             FileName  = $_.Name
#             SizeBytes = $_.Length
#             SHA256    = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
#         }
#     }

#     # Write to disk
#     $ManifestPath = Join-Path -Path $OutputDir -ChildPath "manifest.json"
#     $Manifest | ConvertTo-Json -Depth 5 | Out-File -FilePath $ManifestPath -Encoding UTF8

#     Write-Verbose "Manifest written to: $ManifestPath"
# }

function Get-TriageBinary {
    # Validate the binary files are present at runtime
    param(
        [Parameter(Mandatory)][string]$Name
    )

    if (-not $global:Binaries.ContainsKey($Name)) {
        # Available: $($global:Binaries.Keys -join ', ')"
        throw "Unknown binary => $Name."
    }
    $Key = [IO.Path]::GetFileNameWithoutExtension($global:Binaries[$Name])
    if (-not $global:TriageSys -or -not $global:TriageSys.ContainsKey($Key)) {
        throw "[ $Key.exe ] is missing from bin\ or failed its hash check; refusing to run it."
    }
    $global:TriageSys[$Key]

    # $Path = $script:Binaries[$Name]
    # $Resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    # return $Resolved.Path
}

function Disable-PSReadLineHistory {
    <#
    .SYNOPSIS
        Best effort. Only affects the current session, and the launch line
        has normally already been written by the time the script runs.
    #>
    try {
        if (Get-Module -Name PSReadLine) {
            Set-PSReadLineOption -HistorySaveStyle SaveNothing -ErrorAction Stop
            Show-Message -Message "PSReadLine history saving disabled for this session." -Level INFO -AddToLog
        }
        else {
            Show-Message -Message "PSReadLine not loaded (non-interactive launch); nothing to disable." -Level INFO -AddToLog
        }
    }
    catch {
        Show-Message -Message "Could not disable PSReadLine history => $( $_.Exception.Message )" -Level WARNING -AddToLog
    }
}

function Write-LaunchContext {
    # Records how the tool was started and the state of the operator's history
    # file, so an examiner can later separate tool-caused changes from the
    # subject's activity.
    $Args    = [Environment]::GetCommandLineArgs()
    $NoProf  = [bool]($Args | Where-Object { $_ -like "-NoProf*" })
    $Hist    = Join-Path -Path $env:APPDATA -ChildPath "Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"

    Show-Message -Message "Launch command line => $( [Environment]::CommandLine )" -Level INFO -AddToLog
    Show-Message -Message "PowerShell $( $PSVersionTable.PSVersion ), -NoProfile used: $NoProf, operator account: $env:USERDOMAIN\$env:USERNAME" -Level INFO -AddToLog

    if (-not $NoProf) {
        Show-Message -Message "Not launched with -NoProfile; target profile scripts may have run." -Level WARNING -AddToLog
    }

    if (Test-Path -LiteralPath $Hist) {
        $Item = Get-Item -LiteralPath $Hist -Force
        Show-Message -Message "Operator PSReadLine history at start: $Hist, $( $Item.Length ) bytes, last write (UTC) $( $Item.LastWriteTimeUtc.ToString('o') )" -Level INFO -AddToLog
    }
    else {
        Show-Message -Message "Operator PSReadLine history file not present at start." -Level INFO -AddToLog
    }
}

function Initialize-TriageSystemTools {
    param(
        [Parameter(Mandatory)][string]$ToolkitRoot
    )

    $Folder = Join-Path -Path $ToolkitRoot -ChildPath "bin"
    $ManifestPath = Join-Path -Path $Folder -ChildPath "__hashes.json"
    $global:TriageSys = @{}

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        Show-Message -Message "No trusted tool manifest at $ManifestPath." -Level WARNING -AddToLog
        return
    }

    try {
        $Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Show-Message -Message "Could not read $ManifestPath => $( $_.Exception.Message )" -Level ERROR -AddToLog
        return
    }

    $Verified = 0
    $Failed   = 0
    foreach ($Entry in $Manifest.Files) {
        $Path = Join-Path -Path $Folder -ChildPath $Entry.Path

        if (-not (Test-Path -LiteralPath $Path)) {
            Show-Message -Message "Listed in manifest but missing => $( $Entry.Path )" -Level ERROR -AddToLog
            $Failed++
            continue
        }

        $Actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
        if ($Actual -ne $Entry.SHA256) {
            Show-Message -Message "Hash mismatch for $( $Entry.Path ) => binary is not trusted." -Level ERROR -AddToLog
            $Failed++
            continue
        }

        $Verified++
        # Register only top-level executables as callable tools (skips
        # .mui and anything in subfolders)
        if ($Entry.Path -notmatch "\\" -and $Entry.Path -like "*.exe") {
            $global:TriageSys[[IO.Path]::GetFileNameWithoutExtension($Entry.Path)] = $Path
        }
    }

    Show-Message -Message "Trusted tools: $Verified files verified, $Failed failed. Callable => $( $global:TriageSys.Keys -join ', ' )" -Level INFO -AddToLog -MessageColor Green

    <#

    # --- To import data from a CSV rather than a JSON file -----
    foreach ($Row in (Import-Csv (Join-Path -Path $Folder -ChildPath "bin_hashes.csv"))) {
        $Path = Join-Path -Path $Folder -ChildPath $Row.Name
        if (-not (Test-Path -LiteralPath $Path)) { continue }

        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash -eq $Row.SHA256) {
            $global:TriageSys[[IO.Path]::GetFileNameWithoutExtension($Row.Name)] = $Path
        }
        else {
            Show-Message -Message "Hash mismatch for '$( $Row.Name )', not trusted." -Level ERROR -AddToLog
        }
    }
    Show-Message -Message "Trusted system tools loaded: $( $global:TriageSys.Keys -join ', ')" -Level INFO -AddToLog
    #>
}

function Test-TriageInteractive {
    <#
    .SYNOPSIS
        False under EDR/remote shells, SYSTEM sessions, redirected stdin, or
        powershell.exe -NonInteractive
    #>
    if (-not [Environment]::UserInteractive) {
        return $false
    }
    if ([Environment]::GetCommandLineArgs() -match "^-NonI") {
        return $false
    }
    try {
        if ([Console]::IsInputRedirected) { return $false }
    }
    catch { }
    return $true
}

function Read-YesNo {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [bool]$Default = $false
    )
    $Suffix = if ($Default) { "(Y/n)" } else { "(y/N)" }
    while ($true) {
        $Answer = (Read-LogHost -Prompt "$Prompt $Suffix : ").Trim()
        if ($Answer -eq "") {
            return $Default
        }
        if ($Answer -match "^(y|yes)$") {
            return $true
        }
        if ($Answer -match "^(n|no)$") {
            return $false
        }
        Show-Message -Message "Please enter y or n." -Level WARNING
    }
}

function Read-Required {
    param(
        [Parameter(Mandatory)][string]$Prompt
        )
    do { $Value = (Read-LogHost -Prompt $Prompt).Trim() } while (-not $Value)
    $Value
}

function Show-TriageBanner {
    $IntroBanner = @"

+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
|                                         |
|   NOVA ICAC VECTOR Triage Application   |
|   Compiled by : Michael Sponheimer      |
|   Last Updated : $Dlu            |
|                                         |
+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+

[1] You are about to run the NOVA ICAC VECTOR Triage Application.
[2] PURPOSE: Gather information from the target machine and
    save the data to outside storage device.
[3] The results will automatically be stored in a directory that
    is automatically created in the same directory from where this
    script is run.
[4] You will be asked a few questions now. After you confirm, collection runs
    with no further prompts.
[5] **IMPORTANT** DO NOT VIEW THE RESULTS OF THE SCAN ON THE TARGET
    MACHINE. MOVE THE COLLECTION DEVICE TO A FORENSIC MACHINE BEFORE
    OPENING ANY FILES!
[6] DO NOT close any pop-up windows that may appear.
[7] To get help for this script, run 'Get-Help .\run-triage.ps1'
    command from a PowerShell CLI prompt.
[8] To exit this script at anytime, press [Ctrl + C].

"@


    Show-Message -Message $IntroBanner -NoTime -MessageColor DarkYellow
}

function Write-CaseInfo {
    # Stores the operator/case details as data (they were only logged before).
    # Written before hashing, so it is covered by the hash manifest.
    param(
        [Parameter(Mandatory)][string]$ResultsFolder,
        [Parameter(Mandatory)][string]$Operator,
        [string]$Agency,
        [Parameter(Mandatory)][string]$CaseNumber,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Selected
    )

    $Now  = Get-Date
    $Info = [ordered]@{
        ToolVersion = [string](Get-Module -Name triage | Select-Object -First 1).Version
        Operator = $Operator
        Agency = $Agency
        CaseNumber = $CaseNumber
        ComputerName = $env:COMPUTERNAME
        RunAsUser = "$env:USERDOMAIN\$env:USERNAME"
        StartUtc = $Now.ToUniversalTime().ToString("o")
        LocalUtcOffset = [TimeZoneInfo]::Local.GetUtcOffset($Now).ToString()
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        CommandLine = [Environment]::CommandLine
        Options = $Selected
        KnownTargetChanges = @(
            "HKCU\Software\Sysinternals\PsInfo\EulaAccepted set for $env:USERDOMAIN\$env:USERNAME (psinfo -accepteula)"
            "Typical execution artifacts (Prefetch, Amcache, ShimCache) for powershell.exe and each tool run from bin\ (confirm on a lab VM)"
        )
    }
    $Info | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path -Path $ResultsFolder -ChildPath "case_info.json") -Encoding UTF8
}

function Invoke-RegistryCommand {
    <#
    .SYNOPSIS
        Runs a registry read. A missing key/path is logged as "no data";
        any other problem (access denied, etc.) is logged as an ERROR.
    #>
    param([Parameter(Mandatory)][scriptblock]$Command)

    # 2>&1 turns non-terminating errors into objects we can inspect
    # instead of printing them
    $Output = & $Command 2>&1
    $Errors = @($Output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    $Data   = @($Output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })

    foreach ($E in $Errors) {
        if ($E.FullyQualifiedErrorId -like "PathNotFound*") {
            Show-Message -Message "No data found for registry key => $( $E.TargetObject )" -Level INFO -AddToLog -MessageColor Yellow
        }
        else {
            Show-Message -Message "Registry read problem => $( $E.Exception.Message )" -Level ERROR -AddToLog
        }
    }

    # Empty when nothing was found, so the caller sees $null
    $Data
}

function Clear-TriageHives {
    # Unloads every TRIAGE_* hive, including ones left behind by a crashed or interrupted run.
    [CmdletBinding()]
    param()

    [gc]::Collect(); [gc]::WaitForPendingFinalizers()   # release provider handles first

    $Stale = @(Get-ChildItem -LiteralPath 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like 'TRIAGE_*' })

    foreach ($K in $Stale) {
        $Name = $K.PSChildName
        & reg.exe unload "HKU\$Name" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Start-Sleep -Seconds 2
            [gc]::Collect(); [gc]::WaitForPendingFinalizers()
            & reg.exe unload "HKU\$Name" 2>&1 | Out-Null
        }
        if ($LASTEXITCODE -eq 0) {
            Show-Message -Message "Unloaded hive $Name" -Level INFO -AddToLog
        }
        else {
            Show-Message -Message "Could not unload hive $Name. Close other PowerShell windows and run: reg unload HKU\$Name" -Level ERROR -AddToLog
        }
    }
}