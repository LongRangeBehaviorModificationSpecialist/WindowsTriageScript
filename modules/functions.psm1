# functions.psm1

# # List of file types to use in some commands
# $global:ExecutableFileTypes = @(
#     "*.BAT", "*.BIN", "*.CGI", "*.CMD", "*.COM", "*.DLL", "*.EXE",
#     "*.JAR", "*.JOB", "*.JSE", "*.MSI", "*.PAF", "*.PS1", "*.SCR",
#     "*.SCRIPT", "*.VB", "*.VBE", "*.VBS", "*.VBSCRIPT", "*.WS", "*.WSF"
# )

$Dlu = "02-Oct-2026"

$global:Binaries = @{
    "EDD"                  = Join-Path $global:ToolkitRoot "bin\EDDv310.exe"
    "ipconfig"             = Join-Path $global:ToolkitRoot "bin\ipconfig.exe"
    "MagnetProcessCapture" = Join-Path $global:ToolkitRoot "bin\MagnetProcessCapture.exe"
    "MagnetRamCapture"     = Join-Path $global:ToolkitRoot "bin\MagnetRAMCapture.exe"
    "netstat"              = Join-Path $global:ToolkitRoot "bin\NETSTAT.EXE"
    "PSInfo"               = Join-Path $global:ToolkitRoot "bin\PsInfo.exe"
    "SQLite3"              = Join-Path $global:ToolkitRoot "bin\sqlite3.exe"
}

function Get-InitialSetup {
    param([string]$OutputRoot)

    if (-not $OutputRoot) {
        $OutputRoot = $global:ToolkitRoot
    }
    if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
        throw "Output folder does not exist: $OutputRoot"
    }

    $RunDate = Get-Date -Format yyyyMMdd_HHmmss

    $Idx  = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1).InterfaceIndex

    $Ipv4 = if ($Idx) { (Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $Idx -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress }
    if (-not $Ipv4) {
        $Ipv4 = 'NoIPv4'
    }

    $MergedName           = "{0}_{1}_{2}" -f $RunDate, $Ipv4, $env:COMPUTERNAME
    $global:ResultsFolder = Join-Path $OutputRoot $MergedName
    $null = New-Item -ItemType Directory -Path $global:ResultsFolder -Force

    $LogFolder      = Join-Path $global:ResultsFolder 'Logs'
    $null           = New-Item -ItemType Directory -Path $LogFolder -Force

    $global:LogFile = Join-Path $LogFolder "$($MergedName)_Script.log"
    $null           = New-Item -ItemType File -Path $global:LogFile -Force
}

function Invoke-TriageTranscript {

    try {
        # Start transcript to record all of the screen output
        $Transcript_beginMsg = "Powershell Transcript started..."
        Start-Transcript -OutputDirectory $LogFolder -IncludeInvocationHeader -NoClobber
        Show-Message -Message $Transcript_beginMsg -Level INFO -AddToLog
    }
    catch {
        $ErrorMsg = "Failed to start Powershell Transcript: $( $_.Exception.Message )"
        Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
    }
}

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
        $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::`
            GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($IsAdmin) {
            $IsAdminMsg = "DFIR Session starting as Administrator..."
            Show-Message -Message $IsAdminMsg -Level INFO -AddToLog
        }
        else {
            $NonAdminMsg = "No Administrator session detected. For the best performance run as Administrator. Not all items can be collected. DFIR Session starting..."
            Show-Message -Message $NonAdminMsg -Level INFO -AddToLog
        }
    }
    catch {
        $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error: $( $_.Exception.Message )"
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
        if ($Level -eq "SUCCESS") {
            $Message = "Process completed. Output saved to => '$( [System.IO.Path]::GetFileName($File) )'"
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
            Write-Host "`n[$Timestamp] " -ForegroundColor $TimestampColor -NoNewLine
            Write-Host $Message -ForegroundColor $DisplayColor
        }
        else {
            Write-Host "[$Timestamp] " -ForegroundColor $TimestampColor -NoNewLine
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
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    process {
        if (-not $Message) {
            Write-Error -Message "The '-Message' parameter cannot be empty."
            return
        }

        $Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        "[$Timestamp] $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    }
}

function Write-OutputToFile {
    # Writes the results of the commands to the $OutputFile

    param(
        [Parameter(Mandatory = $false)]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [System.Object]$Data,

        [Parameter(Mandatory = $true)]
        [string]$OutputFile,

        [switch]$Append
    )

    begin {
        $CommandString = "Command: $( $Command.ToString() )`n`n"
    }
    process {
        if (-not $Data) {
            "$CommandString No data was found when running this function." |
                Out-File -FilePath $OutputFile
        }
        else {
            if (-not $Append) {
                $CommandString | Out-File -FilePath $OutputFile -Encoding UTF8
            }
            else {
                $CommandString | Out-File -FilePath $OutputFile -Encoding UTF8 -Append
            }
            $Data | Out-File -FilePath $OutputFile -Encoding UTF8 -Append
        }
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
            $FolderCreatedMsg = "'$FolderNameText' directory created successfully"
            Show-Message -Message $FolderCreatedMsg -Level INFO -AddToLog -SpaceAbove
        }
        else {
            # Show-Message -Message "The necessary sub-directory does not exist `
            #     or could not be created => '$FolderNameText'" -Level ERROR -AddToLog
            # return
            continue
        }
    }
    if ($Type -eq "FILE") {
        $FileNameText = $(Split-Path -Path $FileName -Leaf)
        if (Test-Path $FileName) {
            $FileCreatedMsg = "The '$FileNameText' file was created successfully."
            Show-Message -Message $FileCreatedMsg -Level INFO -AddToLog
        }
        else {
            # Show-Message -Message "There was an error creating the '$($FileNameText)' file." -Level ERROR -AddToLog
            # return
            continue
        }
    }
}

function Get-PerUserRegistryValue {
    param([Parameter(Mandatory)][string]$SubKey)

    foreach ($U in ($global:TriageUserHives | Where-Object Root)) {
        $Path = "$($U.Root)\$SubKey"
        if (-not (Test-Path -LiteralPath $Path)) { continue }

        $Props = Get-ItemProperty -LiteralPath $Path
        foreach ($P in ($Props.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' })) {
            [pscustomobject]@{
                UserName  = $U.UserName
                SID       = $U.Sid
                Key       = "HKU\<SID>\$SubKey"
                ValueName = $P.Name
                Data      = if ($P.Value -is [byte[]]) { ($P.Value | ForEach-Object { $_.ToString('x2') }) -join '' }
                            else { $P.Value -join '; ' }
            }
        }
    }
}

function Get-PerUserRegistrySubKey {
    # Same idea as Get-PerUserRegistryValue, but lists the *subkeys* (MountPoints2, EscDomains)
    param([Parameter(Mandatory)][string]$SubKey)

    foreach ($U in ($global:TriageUserHives | Where-Object Root)) {
        $Path = "$($U.Root)\$SubKey"
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
        if ($EnumerateSubKeys) { Get-PerUserRegistrySubKey -SubKey $Key }
        else                   { Get-PerUserRegistryValue  -SubKey $Key }
    }
    Write-OutputToCsv -Data $Data -OutputFile $OutputFile
}

function Mount-TriageUserHives {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$HiveFolder,     # <Results>\Registry_Hives (pristine copies, hashed later)
        [Parameter(Mandatory)][string]$ScratchFolder   # on the COLLECTION drive, deleted at dismount
    )

    $null = New-Item -ItemType Directory -Path $HiveFolder, $ScratchFolder -Force
    $ProfileList = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'

    # S-1-5-21 = local/domain accounts, S-1-12-1 = Entra ID (Azure AD) accounts
    $Keys = Get-ChildItem $ProfileList | Where-Object {
        $_.PSChildName -match '^S-1-(5-21|12-1)-' -and $_.PSChildName -notmatch '\.bak$'
    }

    foreach ($Key in $Keys) {
        $Sid         = $Key.PSChildName
        $ProfilePath = [Environment]::ExpandEnvironmentVariables((Get-ItemProperty $Key.PSPath).ProfileImagePath)
        try   { $UserName = ([Security.Principal.SecurityIdentifier]$Sid).Translate([Security.Principal.NTAccount]).Value }
        catch { $UserName = 'UNRESOLVED\' + (Split-Path $ProfilePath -Leaf) }   # deleted/orphaned account

        $Out    = [ordered]@{ UserName = $UserName; Sid = $Sid; ProfilePath = $ProfilePath
                              Root = $null; MountName = $null; Note = '' }
        $RawDir = Join-Path $HiveFolder $Sid
        $null   = New-Item -ItemType Directory -Path $RawDir -Force

        if (Test-Path "Registry::HKEY_USERS\$Sid") {
            # Logged on: read the live hive, keep a snapshot
            $Out.Root = "Registry::HKEY_USERS\$Sid"
            & reg.exe save "HKU\$Sid" (Join-Path $RawDir 'NTUSER.DAT.regsave') /y | Out-Null
            $Out.Note = if ($LASTEXITCODE -eq 0) { 'live hive; snapshot via reg save' } else { 'live hive; reg save FAILED' }
        }
        else {
            $Src = Join-Path $ProfilePath 'NTUSER.DAT'
            if (-not (Test-Path -LiteralPath $Src)) { $Out.Note = 'no NTUSER.DAT'; [pscustomobject]$Out; continue }

            # 1) Pristine copy + transaction logs go into the evidence folder
            foreach ($F in 'NTUSER.DAT', 'NTUSER.DAT.LOG1', 'NTUSER.DAT.LOG2') {
                $P = Join-Path $ProfilePath $F
                if (Test-Path -LiteralPath $P) { Copy-Item -LiteralPath $P -Destination $RawDir -Force }
            }

            # 2) Load a disposable working copy. The logs must sit next to it, named <hive>.LOG1/.LOG2,
            #    so Windows replays them (a dirty hive otherwise shows stale data).
            $Work = Join-Path $ScratchFolder "$Sid.DAT"
            Copy-Item (Join-Path $RawDir 'NTUSER.DAT') $Work -Force
            foreach ($L in 'LOG1', 'LOG2') {
                $LP = Join-Path $RawDir "NTUSER.DAT.$L"
                if (Test-Path -LiteralPath $LP) { Copy-Item $LP "$Work.$L" -Force }
            }

            $Mount = "TRIAGE_$Sid"
            & reg.exe load "HKU\$Mount" $Work | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $Out.Root = "Registry::HKEY_USERS\$Mount"; $Out.MountName = $Mount
                $Out.Note = 'offline; loaded from working copy'
            }
            else { $Out.Note = 'reg load FAILED' }
        }
        [pscustomobject]$Out
    }
}

function Dismount-TriageUserHives {
    param([object[]]$Hives, [string]$ScratchFolder)

    [gc]::Collect(); [gc]::WaitForPendingFinalizers()   # release provider handles or unload fails with "Access denied"
    foreach ($H in ($Hives | Where-Object MountName)) {
        & reg.exe unload "HKU\$($H.MountName)" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Start-Sleep -Seconds 2; [gc]::Collect()
            & reg.exe unload "HKU\$($H.MountName)" 2>&1 | Out-Null
        }
        if ($LASTEXITCODE -ne 0) {
            Show-Message -Message "Could not unload hive $($H.MountName)" -Level ERROR -AddToLog
        }
    }
    Remove-Item $ScratchFolder -Recurse -Force -ErrorAction SilentlyContinue
}

function New-CaseManifest {
    param(
        [Parameter(Mandatory)][string]$CaseNumber,
        [Parameter(Mandatory)][string]$Examiner,
        [Parameter(Mandatory)][string]$Agency
    )

    return [ordered]@{
        SchemaVersion       = "1.0"
        CaseID              = $CaseNumber
        Examiner            = $Examiner
        Agency              = $Agency
        ComputerName        = $env:COMPUTERNAME
        OperatingSystem     = (Get-CimInstance Win32_OperatingSystem).Caption
        AcquisitionStartUTC = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        ToolRuns            = [System.Collections.Generic.List[object]]::new()
    }
}

function Complete-CaseManifest {
    param(
        [Parameter(Mandatory)][hashtable]$Manifest,
        [Parameter(Mandatory)][string]$OutputDir
    )

    # Finalize metadata
    $Manifest.AcquisitionEndUTC = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $Manifest.DurationMinutes   = [math]::Round(
        ((Get-Date) - [datetime]::Parse($Manifest.AcquisitionStartUTC)).TotalMinutes, 2
    )

    # Compute hashes for every artifact
    $Manifest.Artifacts = Get-ChildItem -Path $OutputDir -File | ForEach-Object {
        [ordered]@{
            FileName  = $_.Name
            SizeBytes = $_.Length
            SHA256    = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
        }
    }

    # Write to disk
    $ManifestPath = Join-Path $OutputDir 'manifest.json'
    $Manifest | ConvertTo-Json -Depth 5 | Out-File -FilePath $ManifestPath -Encoding UTF8

    Write-Verbose "Manifest written to: $ManifestPath"
}

function Get-TriageBinary {
    # Validate the binary files are present at runtime
    param([Parameter(Mandatory)][string]$Name)

    if (-not $script:Binaries.ContainsKey($Name)) {
        throw "Unknown binary: '$Name'. Available: $($script:Binaries.Keys -join ', ')"
    }

    $Path = $script:Binaries[$Name]
    $Resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    return $Resolved.Path
}

function Disable-PSReadLineHistory {
    # Best effort. Only affects the current session, and the launch line
    # has normally already been written by the time the script runs.
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
        Show-Message -Message "Could not disable PSReadLine history: $( $_.Exception.Message )" -Level WARNING -AddToLog
    }
}

function Write-LaunchContext {
    # Records how the tool was started and the state of the operator's history
    # file, so an examiner can later separate tool-caused changes from the
    # subject's activity.
    $Args    = [Environment]::GetCommandLineArgs()
    $NoProf  = [bool]($Args | Where-Object { $_ -like '-NoProf*' })
    $Hist    = Join-Path $env:APPDATA 'Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt'

    Show-Message -Message "Launch command line: $( [Environment]::CommandLine )" -Level INFO -AddToLog
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

    $Folder = Join-Path $ToolkitRoot "bin"
    $ManifestPath = Join-Path $Folder "__hashes.json"
    $global:TriageSys = @{}

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        Show-Message -Message "No trusted tool manifest at '$ManifestPath'." -Level WARNING -AddToLog
        return
    }

    try {
        $Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Show-Message -Message "Could not read '$ManifestPath' => $( $_.Exception.Message )" -Level ERROR -AddToLog
        return
    }

    $Verified = 0
    $Failed   = 0
    foreach ($Entry in $Manifest.Files) {
        $Path = Join-Path $Folder $Entry.Path

        if (-not (Test-Path -LiteralPath $Path)) {
            Show-Message -Message "Listed in manifest but missing => '$( $Entry.Path )'" -Level ERROR -AddToLog
            $Failed++
            continue
        }

        $Actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
        if ($Actual -ne $Entry.SHA256) {
            Show-Message -Message "Hash mismatch for '$( $Entry.Path )' => binary is not trusted." -Level ERROR -AddToLog
            $Failed++
            continue
        }

        $Verified++
        # Register only top-level executables as callable tools (skips
        # .mui and anything in subfolders)
        if ($Entry.Path -notmatch '\\' -and $Entry.Path -like '*.exe') {
            $global:TriageSys[[IO.Path]::GetFileNameWithoutExtension($Entry.Path)] = $Path
        }
    }

    Show-Message -Message "Trusted tools: $Verified files verified, $Failed failed. Callable: $($global:TriageSys.Keys -join ', ')" -Level INFO -AddToLog

    <#

    # --- To import data from a CSV rather than a JSON file -----
    foreach ($Row in (Import-Csv (Join-Path $Folder "bin_hashes.csv"))) {
        $Path = Join-Path $Folder $Row.Name
        if (-not (Test-Path -LiteralPath $Path)) { continue }

        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash -eq $Row.SHA256) {
            $global:TriageSys[[IO.Path]::GetFileNameWithoutExtension($Row.Name)] = $Path
        }
        else {
            Show-Message -Message "Hash mismatch for '$($Row.Name)', not trusted." -Level ERROR -AddToLog
        }
    }
    Show-Message -Message "Trusted system tools loaded: $($global:TriageSys.Keys -join ', ')" -Level INFO -AddToLog
    #>
}

function Test-TriageInteractive {
    # False under EDR/remote shells, SYSTEM sessions, redirected stdin, or powershell.exe -NonInteractive
    if (-not [Environment]::UserInteractive) { return $false }
    if ([Environment]::GetCommandLineArgs() -match '^-NonI') { return $false }
    try { if ([Console]::IsInputRedirected) { return $false } } catch { }
    return $true
}

function Read-YesNo {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [bool]$Default = $false
    )
    $Suffix = if ($Default) { '(Y/n)' } else { '(y/N)' }
    while ($true) {
        $Answer = (Read-LogHost -Prompt "$Prompt $Suffix : ").Trim()
        if ($Answer -eq '') {
            return $Default
        }
        if ($Answer -match '^(y|yes)$') {
            return $true
        }
        if ($Answer -match '^(n|no)$') {
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

+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
|                                     |
|   VECTOR Triage Script              |
|   Compiled by : Michael Sponheimer  |
|   Last Updated : $Dlu        |
|                                     |
+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+

[1] You are about to run the VECTOR Windows Triage Script.
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


    Show-Message -Message $IntroBanner -NoTime -MessageColor Green
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
        StartUtc = $Now.ToUniversalTime().ToString('o')
        LocalUtcOffset = [TimeZoneInfo]::Local.GetUtcOffset($Now).ToString()
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        CommandLine = [Environment]::CommandLine
        Options = $Selected
    }
    $Info | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $ResultsFolder 'case_info.json') -Encoding UTF8
}

function Invoke-RegistryCommand {
    # Runs a registry read. A missing key/path is logged as "no data";
    # any other problem (access denied, etc.) is logged as an ERROR.
    param([Parameter(Mandatory)][scriptblock]$Command)

    # 2>&1 turns non-terminating errors into objects we can inspect
    # instead of printing them
    $Output = & $Command 2>&1
    $Errors = @($Output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    $Data   = @($Output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })

    foreach ($E in $Errors) {
        if ($E.FullyQualifiedErrorId -like 'PathNotFound*') {
            Show-Message -Message "No data found for registry key => $( $E.TargetObject )" -Level INFO -AddToLog -MessageColor Yellow
        }
        else {
            Show-Message -Message "Registry read problem => $( $E.Exception.Message )" -Level ERROR -AddToLog
        }
    }

    $Data    # empty when nothing was found, so the caller sees $null
}

# ------------------------------
function Get-BinaryFilesHashes {
    <#
    .SYNPOSIS
        Helper function used to create a JSON file containing the hash values
        of the files in the .\bin directory.

        Copy this function to a separate .ps1 file and run it after new files
        are added to the .\bin directory.

        The triage program does not rely on this function.  This function
        does not need to be added to the `FunctionsToExport` array in the
        `triage.psd1` file.

        It is saved here to make it easier to find in the future.
    #>
    $Folder = Join-Path (Get-Location) "bin"
    $Root   = (Resolve-Path $Folder).Path

    $Files = Get-ChildItem -LiteralPath $Root -File -Recurse | Where-Object { $_.Name -ne '__hashes.json' }

    # Hash first, so the count reflects what was actually hashed
    $Entries = @(foreach ($F in $Files) {
        [ordered]@{
            Path        = $F.FullName.Substring($Root.Length).TrimStart('\')
            SHA256      = (Get-FileHash -LiteralPath $F.FullName -Algorithm SHA256).Hash
            Length      = $F.Length
            FileVersion = $F.VersionInfo.FileVersion
        }
    })

    $Manifest = [ordered]@{
        SchemaVersion  = 1
        OsBuild        = $Build
        Algorithm      = 'SHA256'
        FileCount      = $Entries.Count
        CreatedUtc     = (Get-Date).ToUniversalTime().ToString('o')
        SourceComputer = $env:COMPUTERNAME
        Files          = $Entries
    }

    $Manifest | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $Root 'hashes.json') -Encoding UTF8
}