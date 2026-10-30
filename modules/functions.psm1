# functions.psm1

function Get-InitialSetup {
<#
.SYNOPSIS
    Handles the initial setup of the application.
.PARAMETER OutputRoot
    Path to directory where the results of the scan will be saved.
#>
    param(
        [string]$OutputRoot
    )

    if (-not $OutputRoot) {
        $OutputRoot = Get-TriageConfig -Key "ToolkitRoot"
    }

    if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
        throw "Output folder does not exist: $OutputRoot"
    }

    $RunDate = Get-Date -Format yyyyMMdd_HHmmss
    $Idx     = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
                    Sort-Object RouteMetric |
                    Select-Object -First 1).InterfaceIndex
    $Ipv4    = if ($Idx) {
        (Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $Idx -ErrorAction SilentlyContinue |
            Select-Object -First 1).IPAddress }

    if (-not $Ipv4) {
        $Ipv4 = "NoIPv4"
    }

    $MergedName           = "{0}_{1}_{2}" -f $RunDate, $Ipv4, $env:COMPUTERNAME
    $global:ResultsFolder = Join-Path -Path $OutputRoot -ChildPath $MergedName
    $null                 = New-Item -ItemType Directory -Path $global:ResultsFolder -Force

    $LogFolder      = Join-Path -Path $global:ResultsFolder -ChildPath "Logs"
    $null           = New-Item -ItemType Directory -Path $LogFolder -Force

    $global:LogFile = Join-Path -Path $LogFolder -ChildPath "$( $MergedName )_Script.log"
    $null           = New-Item -ItemType File -Path $global:LogFile -Force
}


function Write-OutputToCsv {
<#
.SYNOPSIS
    Handles the writing of the data to a CSV file.
.PARAMETER Data
    The csv data that is going to be written to the file - usually this information is returned during the execution of a function.
.PARAMETER OutputFile
    Path of the file to which the $Data will be saved.
#>
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object]$Data,

        [Parameter(Mandatory)]
        [string]$OutputFile
    )

    process {
        if ($null -eq $Data -or @($Data).Count -eq 0) {
            "No data was found when running this operation." | Out-File -FilePath $OutputFile -Encoding UTF8
        }
        else {
            $Data | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
        }
    }
}


function Show-Message {
<#
.SYNOPSIS
    Handles the display of messages to the terminal (with varions options).
.PARAMETER Message
    temp
.PARAMETER Level
    temp
.PARAMETER File
    temp
.PARAMETER ExecutionTime
    temp
.PARAMETER TimestampColor
    temp
.PARAMETER MessageColor
    temp
.PARAMETER NoTime
    temp
.PARAMETER AddToLog
    temp
.PARAMETER SpaceAbove
    temp
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO","WARNING","ERROR","SUCCESS")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [string[]]$File,

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
            $Names   = @($File | ForEach-Object { [System.IO.Path]::GetFileName($_) })
            $Joined  = $Names -join ", "
            $Message = "Process completed. Output saved to [ $Joined ]"
            if ($ExecutionTime) {
                $Message += " ($ExecutionTime)."
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

        # OUTPUT TO TERMINAL (colors are applied here)
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
                Write-Host "Error occured during $( $MyInvocation.MyCommand.Name ) => CRITICAL: Unable to write to triage log file! Error => $( $_.Exception.Message )" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Error "An uncaught/unknown error occured during $( $MyInvocation.MyCommand.Name ). Error => $( $_.Exception.Message )"
    }
}


function Write-LogMessage {
<#
.SYNOPSIS
    temp
.PARAMETER Message
    temp
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    process {
        if (-not $Message) {
            Write-Error -Message "The `"-Message`" parameter cannot be empty."
            return
        }

        $Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        " [$Timestamp] $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    }
}


function Write-OutputToFile {
<#
.SYNOPSIS
    Writes the results of the commands to the $OutputFile.
.PARAMETER OutputFile
    temp
.PARAMETER Command
    temp
.PARAMETER Data
    temp
.PARAMETER Append
    temp
#>
    param(
        [Parameter(Mandatory)]
        [string]$OutputFile,

        [string]$Command,
        [System.Object]$Data,
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
<#
.SYNOPSIS
    temp
.PARAMETER Prompt
    temp
.PARAMETER TimestampColor
    temp
.PARAMETER PromptColor
    temp
.PARAMETER AsSecureString
    temp
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [ConsoleColor]$TimeStampColor = "Cyan",
        [ConsoleColor]$PromptColor = "Gray",
        [switch]$AsSecureString
    )

    begin {
        $Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
    process {
        Write-Host "[$Timestamp] " -ForegroundColor $TimeStampColor -NoNewline
        Write-Host $Prompt -ForegroundColor $PromptColor -NoNewline

        if ($AsSecureString) {
            Read-Host -AsSecureString
        } else {
            Read-Host
        }
    }
}


function Test-IfExists {
<#
.SYNOPSIS
    temp
.PARAMETER FolderName
    temp
.PARAMETER FileName
    temp
.PARAMETER Type
    temp
#>
    param(
        [string]$FolderName,
        [string]$FileName,

        [ValidateSet("FOLDER","FILE")]
        [string]$Type
    )

    if ($Type -eq "FOLDER") {
        $FolderNameText = $(Split-Path -Path $FolderName -Leaf)
        if (Test-Path $FolderName) {
            Show-Message -Message "[ /$FolderNameText/ ] directory created successfully" -Level INFO -AddToLog -SpaceAbove -MessageColor Magenta
        }
        else {
            return
        }
    }
    if ($Type -eq "FILE") {
        $FileNameText = $(Split-Path -Path $FileName -Leaf)
        if (Test-Path $FileName) {
            Show-Message -Message "[ $FileNameText ] file was created successfully." -Level INFO -AddToLog
        }
        else {
            continue
        }
    }
}


function Get-PerUserRegistryValue {
<#
.SYNOPSIS
    temp
.PARAMETER SubKey
    temp
#>
    param(
        [Parameter(Mandatory)]
        [string]$SubKey
    )

    foreach ($User in ($global:TriageUserHives | Where-Object Root)) {
        $Path = "$( $User.Root )\$SubKey"
        if (-not (Test-Path -LiteralPath $Path)) {
            continue
        }

        $Props = Get-Itemproperty -LiteralPath $Path
        foreach ($Property in ($Props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" })) {
            [PSCustomObject]@{
                UserName  = $User.UserName
                SID       = $User.Sid
                Key       = "HKU\<SID>\$SubKey"
                ValueName = $Property.Name
                Data      = if ($Property.Value -is [byte[]]) { ($Property.Value | ForEach-Object { $_.ToString("x2") }) -join "" } else { $Property.Value -join "; " }
            }
        }
    }
}


function Get-PerUserRegistrySubKey {
<#
.SYNOPSIS
    Same idea as Get-PerUserRegistryValue, but lists the *subkeys* (MountPoints2, EscDomains).
.PARAMETER SubKey
    temp
#>
    param(
        [Parameter(Mandatory)]
        [string]$SubKey
    )

    foreach ($User in ($global:TriageUserHives | Where-Object Root)) {
        $Path = "$( $User.Root )\$SubKey"
        if (-not (Test-Path -LiteralPath $Path)) {
            continue
        }
        Get-ChildItem -LiteralPath $Path | ForEach-Object {
            [PSCustomObject]@{
                UserName   = $User.UserName
                SID        = $User.Sid
                Key        = "HKU\<SID>\$SubKey"
                SubKeyName = $_.PSChildName
            }
        }
    }
}


function Export-PerUserRegistry {
<#
.SYNOPSIS
    temp
.PARAMETER SubKey
    temp
.PARAMETER OutputFile
    temp
.PARAMETER EnumerateSubKeys
    temp
#>
    # One-stop wrapper: gather from every user hive and write a CSV
    param(
        [Parameter(Mandatory)]
        [string[]]$SubKey,

        [Parameter(Mandatory)]
        [string]$OutputFile,

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
<#
.SYNOPSIS
    temp
.PARAMETER HiveFolder
    temp
.PARAMETER ScratchFolder
    temp
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HiveFolder,

        [Parameter(Mandatory)]
        [string]$ScratchFolder
    )

    # Remove leftovers from any earlier run
    Clear-TriageHives

    $null = New-Item -ItemType Directory -Path $HiveFolder, $ScratchFolder -Force
    $ProfileList = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"

    $Keys = Get-ChildItem -LiteralPath $ProfileList | Where-Object {
        $_.PSChildName -match "^S-1-(5-21|12-1)-" -and $_.PSChildName -notmatch "\.bak$"
    }

    foreach ($Key in $Keys) {
        $Sid = $Key.PSChildName
        $Out = [ordered]@{
            UserName    = $null
            Sid         = $Sid
            ProfilePath = $null
            Root        = $null
            MountName   = $null
            Note        = ""
        }
        try {
            $ProfilePath = [Environment]::ExpandEnvironmentVariables(
                (Get-Itemproperty -LiteralPath $Key.PSPath -ErrorAction Stop).ProfileImagePath)
            $Out.ProfilePath = $ProfilePath
            try {
                $Out.UserName = ([Security.Principal.SecurityIdentifier]$Sid).Translate([Security.Principal.NTAccount]).Value
            }
            catch {
                $Out.UserName = "UNRESOLVED\" + (Split-Path -Path $ProfilePath -Leaf)
            }

            $RawDir = Join-Path -Path $HiveFolder -ChildPath $Sid
            $null   = New-Item -ItemType Directory -Path $RawDir -Force

            if (Test-Path -LiteralPath "Registry::HKEY_USERS\$Sid") {
                # Logged on: read the live hive and keep a snapshot
                $Out.Root = "Registry::HKEY_USERS\$Sid"
                & (Get-TriageBinary "reg") save "HKU\$Sid" (Join-Path -Path $RawDir -ChildPath "NTUSER.DAT.regsave") /y 2>&1 | Out-Null
                $Out.Note = if ($LASTEXITCODE -eq 0) {
                    "Live hive; snapshot via reg save"
                }
                else {
                    "Live hive; reg save FAILED"
                }
            }
            else {
                $Src = Join-Path -Path $ProfilePath -ChildPath "NTUSER.DAT"
                if (-not (Test-Path -LiteralPath $Src)) {
                    $Out.Note = "No NTUSER.DAT"
                }
                else {
                    # Pristine copy and transaction logs go into the evidence folder
                    foreach ($File in "NTUSER.DAT", "NTUSER.DAT.LOG1", "NTUSER.DAT.LOG2") {
                        $UserProfile = Join-Path -Path $ProfilePath -ChildPath $File
                        if (Test-Path -LiteralPath $UserProfile) {
                            Copy-Item -LiteralPath $UserProfile -Destination $RawDir -Force -ErrorAction Stop
                        }
                    }

                    # Load a disposable working copy (logs beside it so Windows replays them)
                    $Work = Join-Path -Path $ScratchFolder -ChildPath "$Sid.DAT"
                    Copy-Item -LiteralPath (Join-Path -Path $RawDir -ChildPath "NTUSER.DAT") -Destination $Work -Force -ErrorAction Stop
                    foreach ($Log in "LOG1", "LOG2") {
                        $LP = Join-Path -Path $RawDir -ChildPath "NTUSER.DAT.$Log"
                        if (Test-Path -LiteralPath $LP) {
                            Copy-Item -LiteralPath $LP -Destination "$Work.$Log" -Force -ErrorAction Stop
                        }
                    }

                    $Mount  = "TRIAGE_$Sid"
                    $RegOut = & (Get-TriageBinary "reg") load "HKU\$Mount" $Work 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $Out.Root = "Registry::HKEY_USERS\$Mount"
                        $Out.MountName = $Mount
                        $Out.Note = "Offline; loaded from working copy"
                    }
                    else {
                        $Out.Note = "reg load FAILED => $( $RegOut -join ' ' )"
                    }
                }
            }
        }
        catch {
            # Collectors skip a hive with no Root
            $Out.Root = $null
            $Out.Note = "FAILED => $( $_.Exception.Message )"
            Show-Message -Message "User hive for $Sid could not be prepared => $( $_.Exception.Message )" -Level ERROR -AddToLog
        }
        [PSCustomObject]$Out
    }
}


function Dismount-TriageUserHives {
<#
.SYNOPSIS
    temp
.PARAMETER Hives
    temp
.PARAMETER ScratchFolder
    temp
#>
    # $Hives is kept so existing calls still work
    param(
        [object[]]$Hives,
        [string]$ScratchFolder
    )

    begin {
        # Unloads this run's hives and anything a failed Mount left behind
        Clear-TriageHives
    }
    process {
        if ($ScratchFolder -and (Test-Path -LiteralPath $ScratchFolder)) {
            Remove-Item -LiteralPath $ScratchFolder -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $ScratchFolder) {
                Show-Message -Message "Scratch folder could not be removed [ $ScratchFolder ]" -Level WARNING -AddToLog
            }
        }
    }
}


function Get-TriageBinary {
<#
.SYNOPSIS
    temp
.PARAMETER Name
    temp
#>
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    begin {
        $Bins = (Get-TriageConfig -Key "Binaries")
    }
    process {
        if (-not $Bins.ContainsKey($Name)) {
            throw "Unknown binary [ $Name ]. Available: $( $Bins.Keys -join ', ' )"
        }

        $Key = [System.IO.Path]::GetFileNameWithoutExtension($Bins[$Name])
        if (-not $global:TriageSys -or -not $global:TriageSys.ContainsKey($Key)) {
            throw "[ $Key.exe ] is missing from \bin\ or failed its hash check; refusing to run it."
        }
        $global:TriageSys[$Key]
    }
}

function Disable-PSReadLineHistory {
<#
.SYNOPSIS
    Best effort. Only affects the current session, and the launch line has normally already been written by the time the script runs.
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
<#
.SYNOPSIS
    Records how the tool was started and the state of the operator's history file, so an examiner can later separate tool-caused changes from the subject's activity.
#>
    begin {
        $ArgList = [Environment]::GetCommandLineArgs()
        $NoProf  = [bool]($ArgList | Where-Object { $_ -like "-NoProf*" })
        $Hist    = Join-Path -Path $env:APPDATA -ChildPath "Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    }
    process {
        Show-Message -Message "Launch command line => [ $( [Environment]::CommandLine ) ]" -Level INFO -AddToLog
        Show-Message -Message "PowerShell $( $PSVersionTable.PSVersion ), -NoProfile used: $NoProf, operator account: $env:USERDOMAIN\$env:USERNAME" -Level INFO -AddToLog

        if (-not $NoProf) {
            Show-Message -Message "Not launched with -NoProfile; target profile scripts may have run." -Level WARNING -AddToLog
        }

        if (Test-Path -LiteralPath $Hist) {
            $Item = Get-Item -LiteralPath $Hist -Force
            Show-Message -Message "Operator PSReadLine history at start => [ $Hist ], $( $Item.Length ) bytes, last write (UTC) $( $Item.LastWriteTimeUtc.ToString('o') )" -Level INFO -AddToLog
        }
        else {
            Show-Message -Message "Operator PSReadLine history file not present at start." -Level INFO -AddToLog
        }
    }
}


function Initialize-TriageSystemTools {
<#
.SYNOPSIS
    temp
.PARAMETER ToolkitRoot
    temp
#>
    param(
        [Parameter(Mandatory)]
        [string]$ToolkitRoot
    )

    begin {
        $Folder = Join-Path -Path $ToolkitRoot -ChildPath "bin"
        $ManifestPath = Join-Path -Path $Folder -ChildPath "__hashes.json"
        $global:TriageSys = @{}
    }
    process {
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

        Show-Message -Message "Trusted tools => $Verified files verified, $Failed failed. Callable => $( $global:TriageSys.Keys -join ', ' )" -Level INFO -AddToLog
    }
}


function Show-TriageBanner {
<#
.SYNOPSIS
    temp
#>
    param()

    $Brand = Get-TriageConfig -Key "Branding"
    $IntroBanner = @"

+---------------------------------------------------------+
|                                                         |
|           $($Brand.ToolName)           |
|           Compiled by  : $($Brand.Author)          |
|           Last Updated : $($Brand.DLU)                    |
|                                                         |
+---------------------------------------------------------+

(1) PURPOSE: Gather information from the target machine and
    save the data to an outside storage device.

(2) The results will be stored in a directory that is
    automatically created in the same folder from where
    this script is run.

(3) **IMPORTANT**

    DO NOT VIEW THE RESULTS OF THE SCAN ON THE TARGE MACHINE.
    MOVE THE COLLECTION DEVICE TO A FORENSIC MACHINE BEFORE
    OPENING ANY FILES!

(4) DO NOT close any pop-up windows that may appear.

(5) To view the help for this script, run:

    "Get-Help .\run-triage.ps1"

(6) To exit this script at anytime, press [Ctrl + C].

-----------------------------------------------------------

"@

    Show-Message -Message $IntroBanner -NoTime -MessageColor DarkYellow
}

function Write-CaseInfo {
<#
.SYNOPSIS
    Stores the operator/case details as data (they were only logged before). Written before hashing, so it is covered by the hash manifest.
.PARAMETER ResultsFolder
    temp
.PARAMETER Operator
    temp
.PARAMETER CaseNumber
    temp
.PARAMETER Selected
    temp
.PARAMETER Agency
    temp
#>
    param(
        [Parameter(Mandatory)]
        [string]$ResultsFolder,

        [Parameter(Mandatory)]
        [string]$Operator,

        [Parameter(Mandatory)]
        [string]$CaseNumber,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Selected,

        [string]$Agency
    )

    begin {
        $Now  = Get-Date
        $Info = [ordered]@{
            ToolVersion        = [string](Get-Module -Name triage | Select-Object -First 1).Version
            Operator           = $Operator
            Agency             = $Agency
            CaseNumber         = $CaseNumber
            ComputerName       = $env:COMPUTERNAME
            RunAsUser          = "$env:USERDOMAIN\$env:USERNAME"
            StartUtc           = $Now.ToUniversalTime().ToString("o")
            LocalUtcOffset     = [TimeZoneInfo]::Local.GetUtcOffset($Now).ToString()
            PowerShellVersion  = $PSVersionTable.PSVersion.ToString()
            CommandLine        = [Environment]::CommandLine
            Options            = $Selected
            KnownTargetChanges = @(
                "HKCU\Software\Sysinternals\PsInfo\EulaAccepted set for $env:USERDOMAIN\$env:USERNAME (psinfo -accepteula)"
                "Typical execution artifacts (Prefetch, Amcache, ShimCache) for powershell.exe and each tool run from bin\ (confirm on a lab VM)"
            )
        }
    }
    process {
        $Info | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path -Path $ResultsFolder -ChildPath "case_info.json") -Encoding UTF8
    }
}


function Invoke-RegistryCommand {
<#
.SYNOPSIS
    Runs a registry read. A missing key/path is logged as "no data"; any other problem (access denied, etc.) is logged as an ERROR.
.PARAMETER Command
    temp
#>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Command
    )

    begin {
        # 2>&1 turns non-terminating errors into objects we can inspect instead of printing them
        $Output = & $Command 2>&1
        $Errors = @($Output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
        $Data   = @($Output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
    }
    process {
        foreach ($E in $Errors) {
            if ($E.FullyQualifiedErrorId -like "PathNotFound*") {
                $Msg = "No data found for registry key [ $( $E.TargetObject ) ]"
                Show-Message -Message $Msg -Level INFO -AddToLog -MessageColor Yellow
            }
            else {
                Show-Message -Message "Registry read problem [ $( $E.Exception.Message ) ]" -Level ERROR -AddToLog
            }
        }
        # Empty when nothing was found, so the caller sees $null
        $Data
    }
}


function Clear-TriageHives {
<#
.SYNOPSIS
    Unloads every TRIAGE_* hive, including ones left behind by a crashed or interrupted run.
#>
    [CmdletBinding()]
    param()

    begin {
        # Release provider handles first
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
    }
    process {
        $Stale = @(Get-ChildItem -LiteralPath "Registry::HKEY_USERS" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like "TRIAGE_*" })

        foreach ($K in $Stale) {
            $Name = $K.PSChildName
            & (Get-TriageBinary "reg") unload "HKU\$Name" 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Start-Sleep -Seconds 2
                [gc]::Collect()
                [gc]::WaitForPendingFinalizers()
                & (Get-TriageBinary "reg") unload "HKU\$Name" 2>&1 | Out-Null
            }
            if ($LASTEXITCODE -eq 0) {
                Show-Message -Message "Unloaded hive $Name" -Level INFO -AddToLog
            }
            else {
                Show-Message -Message "Could not unload hive $Name. Close other PowerShell windows and run: 'reg unload HKU\$Name'" -Level ERROR -AddToLog
            }
        }
    }
}


function Import-TriageConfig {
<#
.SYNOPSIS
    This function stays private.  Do not add to the `triage.psd1` file.
.PARAMETER ToolkitRoot
    temp
#>
    [CmdletBinding()]
    param(
        [string]$ToolkitRoot = (Split-Path -Path $PSScriptRoot -Parent)
    )

    $Path = Join-Path -Path $ToolkitRoot -ChildPath "config\TriageConfig.psd1"
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Configuration file not found => [ $Path ]"
    }

    $Cfg = Import-PowerShellDataFile -Path $Path

    foreach ($Required in "Modules", "Binaries", "Defaults") {
        if (-not $Cfg.ContainsKey($Required)) {
            throw "Configuration file [ $Path ] is missing the required key [ $Required ]."
        }
    }

    # Relative -> full paths
    $Full = @{}
    foreach ($Name in $Cfg.Binaries.Keys) {
        $Full[$Name] = Join-Path -Path $ToolkitRoot -ChildPath $Cfg.Binaries[$Name]
    }
    $Cfg.Binaries = $Full

    $Cfg.ToolkitRoot  = $ToolkitRoot
    $Cfg.ConfigPath   = $Path
    $Cfg.ConfigSha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash

    $script:TriageConfig = $Cfg
    # Kept only until every module is migrated
    $global:ToolkitRoot  = $ToolkitRoot
}


function Get-TriageConfig {
<#
.SYNOPSIS
    temp
.PARAMETER Key
    temp
#>
    [CmdletBinding()]
    param(
        [string]$Key
    )

    if (-not $script:TriageConfig) {
        Import-TriageConfig
    }
    if ($Key) {
        return $script:TriageConfig[$Key]
    }
    $script:TriageConfig
}


function Format-TriageDuration {
<#
.SYNOPSIS
    temp
.PARAMETER Span
    temp
#>
    param(
        [Parameter(Mandatory)]
        [TimeSpan]$Span
    )

    begin {
        $Inv = [System.Globalization.CultureInfo]::InvariantCulture
    }
    process {
        if ($Span.TotalSeconds -lt 60) {
            return [string]::Format($Inv, "{0:N2} seconds", $Span.TotalSeconds)
        }
        if ($Span.TotalHours -lt 1) {
            return [string]::Format($Inv, "{0} min {1:00} sec", $Span.Minutes, $Span.Seconds)
        }
        [string]::Format($Inv, "{0} hr {1:00} min {2:00} sec", [int][math]::Floor($Span.TotalHours), $Span.Minutes, $Span.Seconds)
    }
}


function Invoke-TriageTask {
<#
.SYNOPSIS
    temp
.PARAMETER Message
    temp
.PARAMETER Action
    temp
.PARAMETER ExpectedFile
    temp
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [scriptblock]$Action,

        [string[]]$ExpectedFile = @()
    )

    $StartedUtc  = (Get-Date).ToUniversalTime().ToString("o")
    $Sw          = [System.Diagnostics.Stopwatch]::StartNew()
    $ErrorsStart = [int]$global:TriageErrorCount
    $Status      = "OK"

    Show-Message -Message $Message -Level INFO -AddToLog

    try {
        $null = & $Action
    }
    catch {
        $Status = "Failed"
        Show-Message -Message "Execution failed during [ $Action ] => $( $_.Exception.Message )" -Level ERROR -AddToLog
    }

    $Sw.Stop()
    $Time = Format-TriageDuration -Span $Sw.Elapsed

    $Present = [System.Collections.Generic.List[string]]::new()
    $Missing = [System.Collections.Generic.List[string]]::new()
    if ($Status -eq "OK") {
        foreach ($Path in $ExpectedFile) {
            $Hits = if ($Path -match "[\*\?]") {
                @(Get-ChildItem -Path $Path -File -Force -ErrorAction SilentlyContinue)
            }
                    else {
                        @(Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue | Where-Object { $_ -is [System.IO.FileInfo] })
                    }
            if (@($Hits | Where-Object { $_.Length -gt 0 }).Count -gt 0) {
                $Present.Add($Path)
            }
            else {
                $Missing.Add($Path)
            }
        }

        $NewErrors = [int]$global:TriageErrorCount - $ErrorsStart
        if ($Missing.Count -gt 0) {
            $Status = "MissingOutput"
            Show-Message -Message "[ $Message ] finished ($Time) but expected output is missing or empty => $( ($Missing | ForEach-Object { Split-Path -Path $_ -Leaf }) -join ', ' )" -Level ERROR -AddToLog
        }
        elseif ($NewErrors -gt 0) {
            $Status = "CompletedWithErrors"
            Show-Message -Message "[ $Message ] completed with $NewErrors error(s) ($Time). See application log." -Level WARNING -AddToLog
        }
        elseif ($Present.Count -gt 0) {
            Show-Message -File $Present -ExecutionTime $Time -Level SUCCESS -AddToLog
        }
        else {
            Show-Message -Message "Process completed ($Time)." -Level SUCCESS -AddToLog
        }
    }

    if ($global:TriageTimings) {
        $global:TriageTimings.Add([PSCustomObject]@{
            StartedUtc = $StartedUtc
            Task       = $Message
            Seconds    = [math]::Round($Sw.Elapsed.TotalSeconds, 2)
            Status     = $Status
        })
    }
}


function Invoke-TriageTaskList {
<#
.SYNOPSIS
    temp
.PARAMETER Tasks
    temp
.PARAMETER Folder
    temp
#>
    param(
        [Parameter(Mandatory)]
        [object[]]$Tasks,

        [Parameter(Mandatory)]
        [string]$Folder
    )

    foreach ($Task in $Tasks) {
        $Expected = @($Task.Files | Where-Object { $_ } | ForEach-Object { Join-Path -Path $Folder -ChildPath $_ })
        Invoke-TriageTask -Message $Task.Message -Action $Task.Action -ExpectedFile $Expected
    }
}


function New-TriageCopyResult {
<#
.SYNOPSIS
    temp
.PARAMETER Source
    temp
.PARAMETER Destination
    temp
#>
    param(
        [string]$Source,
        [string]$Destination
    )

    [PSCustomObject]@{
        Source            = $Source
        Destination       = $Destination
        Method            = ""
        Status            = "Failed"
        SizeBytes         = $null
        SourceCreatedUtc  = ""
        SourceModifiedUtc = ""
        SourceAccessedUtc = ""
        Detail            = ""
    }
}


function Invoke-TriageRawCopy {
<#
.SYNOPSIS
    temp
.PARAMETER Source
    temp
.PARAMETER Destination
    temp
#>
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    # Throws if missing or failed its hash check
    $Exe  = (Get-TriageBinary "RawCopy")
    $Dir  = Split-Path -Path $Destination -Parent
    $Name = Split-Path -Path $Destination -Leaf
    $null = New-Item -ItemType Directory -Path $Dir -Force
    # Start-Process -Wait: RawCopy may be a GUI-subsystem program, which "&" would not wait for.

    # WorkingDirectory keeps any log file it writes next to the output.
    $ArgList = @("/FileNamePath:`"$Source`"", "/OutputPath:`"$Dir`"", "/OutputName:`"$Name`"")
    $null = Start-Process -FilePath $Exe -ArgumentList $ArgList -WorkingDirectory $Dir -Wait -PassThru -WindowStyle Hidden

    $Out = Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    if (-not $Out -or $Out.Length -eq 0) {
        throw "RawCopy produced no output for [ $Source ]."
    }
}


function Copy-TriageFile {
<#
.SYNOPSIS
    temp
.PARAMETER Source
    temp
.PARAMETER Destination
    temp
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $R    = New-TriageCopyResult -Source $Source -Destination $Destination
    $Item = Get-Item -LiteralPath $Source -Force -ErrorAction SilentlyContinue
    if (-not $Item) {
        $R.Status = "NotFound"
        return $R
    }

    $R.SizeBytes         = $Item.Length
    $R.SourceCreatedUtc  = $Item.CreationTimeUtc.ToString("o")
    $R.SourceModifiedUtc = $Item.LastWriteTimeUtc.ToString("o")
    $R.SourceAccessedUtc = $Item.LastAccessTimeUtc.ToString("o")

    $null = New-Item -ItemType Directory -Path (Split-Path -Path $Destination -Parent) -Force

    $In = $null
    $Out = $null

    try {
        $Share    = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
        $In       = [System.IO.File]::Open($Source, "Open", "Read", $Share)
        $Out      = [System.IO.File]::Open($Destination, "Create", "Write")
        $In.CopyTo($Out)
        $R.Method = "SharedRead"
        $R.Status = "OK"
    }
    catch { $R.Detail = $_.Exception.Message }
    finally {
        if ($Out) {
            $Out.Dispose()
        }
        if ($In) {
            $In.Dispose()
        }
    }

    if ($R.Status -eq "OK") {
        # Keep the source's modified time
        (Get-Item -LiteralPath $Destination -Force).LastWriteTimeUtc = $Item.LastWriteTimeUtc
        return $R
    }

    # Exclusively locked: read it from the volume instead
    Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    try {
        Invoke-TriageRawCopy -Source $Source -Destination $Destination
        $R.Method = "RawCopy"
        $R.Status = "OK"
        $R.Detail = ""
    }
    catch {
        $R.Status = "Locked"
        $R.Detail = "$( $R.Detail ) | RawCopy => $( $_.Exception.Message )"
    }
    $R
}


function Copy-TriageRawFile {
<#
.SYNOPSIS
    Always uses RawCopy (for $MFT, $UsnJrnl).
.PARAMETER Source
    temp
.PARAMETER Destination
    temp
#>
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $R = New-TriageCopyResult -Source $Source -Destination $Destination
    $R.Method = "RawCopy"
    try {
        Invoke-TriageRawCopy -Source $Source -Destination $Destination
        $R.Status = "OK"
        $R.SizeBytes = (Get-Item -LiteralPath $Destination -Force).Length
    }
    catch {
        $R.Detail = $_.Exception.Message
    }
    $R
}


function Save-TriageRegistryHive {
<#
.SYNOPSIS
    temp
.PARAMETER HiveKey
    temp
.PARAMETER Destination
    temp
#>
    # reg save: a consolidated export of a loaded hive
    param(
        [Parameter(Mandatory)]
        [string]$HiveKey,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $R = New-TriageCopyResult -Source $HiveKey -Destination $Destination
    $R.Method = "reg save"
    try {
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $Destination -Parent) -Force
        $Raw = & (Get-TriageBinary "reg") save $HiveKey $Destination /y 2>&1
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $Destination)) {
            $R.Status    = "OK"
            $R.SizeBytes = (Get-Item -LiteralPath $Destination -Force).Length
        }
        else {
            $R.Detail = ($Raw | ForEach-Object { "$_" }) -join " "
        }
    }
    catch {
        $R.Detail = $_.Exception.Message
    }
    $R
}


function Copy-TriageFolderBackup {
<#
.SYNOPSIS
    Robocopy in backup mode: reads folders whose ACL excludes administrators.
.PARAMETER Source
    temp
.PARAMETER Destination
    temp
#>
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $R = New-TriageCopyResult -Source $Source -Destination $Destination
    $R.Method = "robocopy /B"
    try {
        $Raw = & (Get-TriageBinary "robocopy") $Source $Destination /E /B /XJ /COPY:DAT /DCOPY:DAT /R:0 /W:0 /NP /NJH /NJS /NDL /NC /NS 2>&1
        if ($LASTEXITCODE -ge 8) {
            $R.Detail = "robocopy exit $LASTEXITCODE => $( ($Raw | ForEach-Object { "$_" }) -join ' ' )"
        }
        else {
            $Files = @(Get-ChildItem -LiteralPath $Destination -Recurse -File -Force -ErrorAction SilentlyContinue)
            $R.Status = if ($Files.Count -gt 0) {
                "OK"
            }
            else {
                "NotFound"
            }
            $R.SizeBytes = ($Files | Measure-Object Length -Sum).Sum
        }
    }
    catch {
        $R.Detail = $_.Exception.Message
    }
    $R
}
