# functions.psm1

function Get-InitialSetup {
    <#
    .SYNOPSIS
        Creates the results folder and log file for a triage run.
    .DESCRIPTION
        Builds a uniquely named results folder under OutputRoot, named
        <yyyyMMdd_HHmmss>_<IPv4>_<COMPUTERNAME>, and creates a "Logs" subfolder containing an empty
        "<name>_Script.log" file. The IPv4 address is taken from the interface that owns the lowest-metric
        default route (0.0.0.0/0). If no address can be found, "NoIPv4" is used in the folder name.

        The function sets two global variables that the rest of the toolkit relies on:
            $global:ResultsFolder  Full path to the new results folder.
            $global:LogFile        Full path to the new log file.

        If OutputRoot is not supplied, the "ToolkitRoot" value from TriageConfig.psd1 is used.
    .PARAMETER OutputRoot
        Existing directory in which the results folder will be created. Defaults to the ToolkitRoot value
        returned by Get-TriageConfig.
    .EXAMPLE
        Get-InitialSetup
        Creates the results folder beside the toolkit and sets $global:ResultsFolder and $global:LogFile.
    .EXAMPLE
        Get-InitialSetup -OutputRoot "E:\Collections"
        Creates the results folder on the E: drive.
    .INPUTS
        None.
    .OUTPUTS
        None. Results are returned through the $global:ResultsFolder and $global:LogFile variables.
    .NOTES
        Throws a terminating error if OutputRoot does not exist.
    #>
    [CmdletBinding()]
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
            Select-Object -First 1).IPAddress
    }

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
        Writes collected data to a UTF-8 CSV file.
    .DESCRIPTION
        Exports Data to OutputFile with Export-Csv (no type information header, UTF-8 encoding).
        If Data is $null or an empty collection, a single line of text, "No data was found when running
        this operation.", is written to OutputFile instead, so that the file always exists and the
        examiner can tell "nothing found" apart from "collector failed".

        Note that in the no-data case the file contains plain text rather than CSV content.
    .PARAMETER Data
        The objects to write. Typically the output of a collector function. May be $null or empty.
    .PARAMETER OutputFile
        Full path of the CSV file to create. An existing file is overwritten.
    .EXAMPLE
        Write-OutputToCsv -Data (Get-Process) -OutputFile "$global:ResultsFolder\processes.csv"
    .EXAMPLE
        Write-OutputToCsv -Data $null -OutputFile "$global:ResultsFolder\empty.csv"
        Writes the "No data was found" message to empty.csv.
    .INPUTS
        None.
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
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
        Displays a colored, timestamped message in the console and optionally writes it to the log file.
    .DESCRIPTION
        Central messaging function for the toolkit. Prints the message with a UTC timestamp, colored by
        severity (SUCCESS = Green, WARNING = Yellow, ERROR = Red, INFO = MessageColor).

        Side effects:
            - Level ERROR increments $global:TriageErrorCount.
            - Level WARNING increments $global:TriageWarningCount.

            Invoke-TriageTask uses these counters to decide whether a task "completed with errors".

            - With -AddToLog, a plain-text entry "[timestamp] [LEVEL] message" is appended to $LogFile.

            If the log write fails, a critical error is printed to the console so the examiner knows the log is incomplete.

        When Level is SUCCESS and -File is supplied, the message text is generated automatically:
        "Process completed. Output saved to [ file1, file2 ]", followed by the ExecutionTime if given.
    .PARAMETER Message
        Text to display. Ignored when Level is SUCCESS and File is supplied (the text is generated).
    .PARAMETER Level
        Severity of the message: INFO (default), WARNING, ERROR or SUCCESS.
    .PARAMETER File
        One or more file paths. Only the file names are shown. Used with Level SUCCESS to build the
        "Output saved to" message.
    .PARAMETER ExecutionTime
        Pre-formatted duration text (see Format-TriageDuration) appended to the auto-generated SUCCESS
        message.
    .PARAMETER TimestampColor
        Console color of the "[timestamp]" prefix. Default is Cyan.
    .PARAMETER MessageColor
        Console color for INFO messages. Other levels use their fixed severity color. Default is Gray.
    .PARAMETER NoTime
        Omits the timestamp prefix. Used for banners and other free-form text.
    .PARAMETER AddToLog
        Also appends the message to the log file in $LogFile.
    .PARAMETER SpaceAbove
        Prints a blank line above the message (ignored when -NoTime is used).
    .EXAMPLE
        Show-Message -Message "Collecting event logs" -Level INFO -AddToLog
    .EXAMPLE
        Show-Message -Message "Could not read key" -Level ERROR -AddToLog
    .EXAMPLE
        Show-Message -Level SUCCESS -File "C:\Results\services.csv" -ExecutionTime "1.52 seconds" -AddToLog
    .INPUTS
        None.
    .OUTPUTS
        None. Output is written to the host and, optionally, to the log file.
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
        if ($AddToLog -and $global:LogFile) {
            try {
                $LogMessage | Out-File -FilePath $global:LogFile -Append -Encoding UTF8 -NoClobber
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
        Appends a timestamped line to the triage log file without writing to the console.
    .DESCRIPTION
        Writes " [yyyy-MM-ddTHH:mm:ss.fffZ] Message" (UTC) to the file named by $LogFile using UTF-8
        encoding. Use this when something belongs in the log but should not appear on screen; use
        Show-Message -AddToLog when it should do both.

        Unlike Show-Message, this function does not record a severity level and does not update the
        error or warning counters.
    .PARAMETER Message
        Text to write to the log. An empty value produces an error and nothing is written.
    .EXAMPLE
        Write-LogMessage -Message "Operator confirmed the target is powered by AC."
    .INPUTS
        None.
    .OUTPUTS
        None.
    .NOTES
        Requires $LogFile to have been set by Get-InitialSetup.
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
        " [$Timestamp] $Message" | Out-File -FilePath $global:LogFile -Append -Encoding UTF8
    }
}


function Write-OutputToFile {
    <#
    .SYNOPSIS
        Writes command output to a plain-text file, with an optional "Command:" header.
    .DESCRIPTION
        Formats Data as it would appear in the console (Out-String, 4096 characters wide so tables are not
        truncated) and writes it to OutputFile as UTF-8. If Command is supplied, a "Command: <text>" header
        and a blank line are written first. If Data is empty or $null, the body becomes "No data was found
        when running this function."

        Use -Append to add several command results to the same file.
    .PARAMETER OutputFile
        Full path of the text file to write.
    .PARAMETER Command
        Text of the command that produced the data. Written as a header for documentation purposes only;
        it is not executed.
    .PARAMETER Data
        The object(s) to write. Rendered with Out-String.
    .PARAMETER Append
        Adds to the end of OutputFile instead of overwriting it.
    .EXAMPLE
        Write-OutputToFile -OutputFile "$global:ResultsFolder\network.txt" -Command "ipconfig /all" -Data (ipconfig /all)
    .EXAMPLE
        Write-OutputToFile -OutputFile $File -Command "arp -a" -Data (arp -a) -Append
    .INPUTS
        None.
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
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
    else {
        ($Header + $Body) | Out-File -FilePath $OutputFile -Encoding UTF8
    }
}


function Read-LogHost {
    <#
    .SYNOPSIS
        Prompts the operator for input, using the same timestamped format as Show-Message.
    .DESCRIPTION
        Displays "[UTC timestamp] Prompt" in color and then reads a line with Read-Host. Optionally reads
        the response as a SecureString. The timestamp is captured when the function starts.

        The prompt itself is not written to the log file.
    .PARAMETER Prompt
        Text shown to the operator.
    .PARAMETER TimestampColor
        Console color of the timestamp. Default is Cyan.
    .PARAMETER PromptColor
        Console color of the prompt text. Default is Gray.
    .PARAMETER AsSecureString
        Reads the response as a SecureString (input is masked).
    .EXAMPLE
        $Operator = Read-LogHost -Prompt "Enter operator name: "
    .EXAMPLE
        $Secret = Read-LogHost -Prompt "Enter archive password: " -AsSecureString
    .INPUTS
        None.
    .OUTPUTS
        System.String, or System.Security.SecureString when -AsSecureString is used.
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
        }
        else {
            Read-Host
        }
    }
}


function Test-IfExists {
    <#
    .SYNOPSIS
        Confirms that an expected folder or file exists and logs the result.
    .DESCRIPTION
        For Type FOLDER, checks FolderName and, if present, logs "[ /name/ ] directory created
        successfully". For Type FILE, checks FileName and, if present, logs "[ name ] file was created
        successfully". Messages are INFO level and are written to both the console and the log file.

        Nothing is reported when the item does not exist.
    .PARAMETER FolderName
        Full path of the folder to check. Used when Type is FOLDER.
    .PARAMETER FileName
        Full path of the file to check. Used when Type is FILE.
    .PARAMETER Type
        What to check: FOLDER or FILE.
    .EXAMPLE
        Test-IfExists -FolderName "$global:ResultsFolder\Registry" -Type FOLDER
    .EXAMPLE
        Test-IfExists -FileName "$global:ResultsFolder\services.csv" -Type FILE
    .INPUTS
        None.
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
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
            return
        }
    }
}


function Get-PerUserRegistryValue {
    <#
    .SYNOPSIS
        Reads the values of a registry key from every user hive prepared by Mount-TriageUserHives.
    .DESCRIPTION
        For each entry in $global:TriageUserHives that has a Root, reads the value names and data under
        "<Root>\<SubKey>" and returns one object per value. Users whose hive could not be prepared (no Root)
        and users who do not have the key are skipped silently.

        Data formatting: byte arrays are returned as a lowercase hex string; other arrays are joined with
        "; ". The PowerShell housekeeping properties (PSPath, PSParentPath, etc.) are excluded.
    .PARAMETER SubKey
        Registry path relative to the root of the user hive, for example
        "Software\Microsoft\Windows\CurrentVersion\Run".
    .EXAMPLE
        Get-PerUserRegistryValue -SubKey "Software\Microsoft\Windows\CurrentVersion\Run"
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject with the properties UserName, SID, Key, ValueName
        and Data.
    .NOTES
        Requires $global:TriageUserHives to be populated from the output of Mount-TriageUserHives.
        The Key property shows the path as "HKU\<SID>\<SubKey>" regardless of how the hive was mounted.
    #>
    [CmdletBinding()]
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
        Lists the subkeys of a registry key in every user hive prepared by Mount-TriageUserHives.
    .DESCRIPTION
        Companion to Get-PerUserRegistryValue. Instead of reading values, it returns the names of the child
        keys under "<Root>\<SubKey>" for each user hive. Useful for keys whose evidence is the key names
        themselves, such as MountPoints2 or EscDomains. Hives without a Root, and users who do not have
        the key, are skipped silently.
    .PARAMETER SubKey
        Registry path relative to the root of the user hive, for example
        "Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2".
    .EXAMPLE
        Get-PerUserRegistrySubKey -SubKey "Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2"
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject with the properties UserName, SID, Key and SubKeyName.
    .NOTES
        Requires $global:TriageUserHives to be populated from the output of Mount-TriageUserHives.
    #>
    [CmdletBinding()]
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
        Collects one or more registry keys from all user hives and saves the result to a CSV file.
    .DESCRIPTION
        Convenience wrapper around Get-PerUserRegistryValue and Get-PerUserRegistrySubKey. Each key in
        SubKey is read for every user, the combined results are gathered, and Write-OutputToCsv writes them
        to OutputFile. By default the values of each key are collected; with -EnumerateSubKeys the names of
        the child keys are collected instead.
    .PARAMETER SubKey
        One or more registry paths relative to the root of each user hive.
    .PARAMETER OutputFile
        Full path of the CSV file to create.
    .PARAMETER EnumerateSubKeys
        Lists subkey names instead of reading values.
    .EXAMPLE
        Export-PerUserRegistry -SubKey "Software\Microsoft\Windows\CurrentVersion\Run",
            "Software\Microsoft\Windows\CurrentVersion\RunOnce" -OutputFile "$global:ResultsFolder\run_keys.csv"
    .EXAMPLE
        Export-PerUserRegistry -SubKey "Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2" `
            -OutputFile "$global:ResultsFolder\mountpoints2.csv" -EnumerateSubKeys
    .INPUTS
        None.
    .OUTPUTS
        None. Results are written to OutputFile.
    #>
    # One-stop wrapper: gather from every user hive and write a CSV
    [CmdletBinding()]
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
        Makes every user's NTUSER.DAT readable, preserving a copy of each hive as evidence.
    .DESCRIPTION
        Enumerates the local profile list (domain/local user SIDs beginning S-1-5-21 and Entra ID SIDs
        beginning S-1-12-1; ".bak" entries are ignored) and prepares each user's registry hive:

          Logged-on user      The live HKEY_USERS\<SID> hive is used and a snapshot is saved with
                              "reg save" as NTUSER.DAT.regsave.
          Not logged on       NTUSER.DAT, NTUSER.DAT.LOG1 and NTUSER.DAT.LOG2 are copied into
                              HiveFolder\<SID> as evidence. A second, disposable copy (with its logs, so
                              Windows can replay them) is placed in ScratchFolder and loaded as
                              HKEY_USERS\TRIAGE_<SID>.

        Any hives left over from a previous run are unloaded first by calling Clear-TriageHives. A failure
        for one user is logged as an ERROR and the remaining users are still processed.

        Call Dismount-TriageUserHives when finished.
    .PARAMETER HiveFolder
        Folder in which the preserved hive files are stored (one subfolder per SID). Created if missing.
    .PARAMETER ScratchFolder
        Temporary folder for the working copies that are loaded into the registry. Created if missing.
        Delete it afterward with Dismount-TriageUserHives.
    .EXAMPLE
        $global:TriageUserHives = Mount-TriageUserHives -HiveFolder "$global:ResultsFolder\Hives" `
            -ScratchFolder "$env:TEMP\TriageScratch"
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject, one per profile, with the properties UserName, Sid,
        ProfilePath, Root, MountName and Note. Root is $null when the hive could not be prepared;
        Note explains what happened.
    .NOTES
        Requires an elevated session and the trusted "reg" binary registered by
        Initialize-TriageSystemTools.
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
                & (Get-TriageBinary "reg") save "HKU\$Sid" (Join-Path $RawDir "NTUSER.DAT.regsave") /y 2>&1 |
                    Out-Null

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
                            Copy-Item -LiteralPath $UserProfile -Destination $RawDir -Force
                        }
                    }

                    # Load a disposable working copy (logs beside it so Windows replays them)
                    $Work = Join-Path -Path $ScratchFolder -ChildPath "$Sid.DAT"
                    Copy-Item -LiteralPath (Join-Path $RawDir "NTUSER.DAT") -Destination $Work -Force
                    foreach ($Log in "LOG1", "LOG2") {
                        $LP = Join-Path -Path $RawDir -ChildPath "NTUSER.DAT.$Log"

                        if (Test-Path -LiteralPath $LP) {
                            Copy-Item -LiteralPath $LP -Destination "$Work.$Log" -Force
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
            Show-Message -Message "User hive for $Sid could not be prepared => $( $_.Exception.Message )" `
                -Level ERROR -AddToLog
        }
        [PSCustomObject]$Out
    }
}


function Dismount-TriageUserHives {
    <#
    .SYNOPSIS
        Unloads the user hives mounted by Mount-TriageUserHives and removes the scratch folder.
    .DESCRIPTION
        Calls Clear-TriageHives to unload every TRIAGE_* hive (including any left behind by a failed run),
        then deletes ScratchFolder and its contents. If the folder cannot be removed, a WARNING is logged.
        The preserved evidence copies in the hive folder are not touched.
    .PARAMETER Hives
        The objects returned by Mount-TriageUserHives. Accepted so that existing calls keep working; it is
        not used, because all TRIAGE_* hives are unloaded regardless.
    .PARAMETER ScratchFolder
        The scratch folder that was passed to Mount-TriageUserHives. Skipped if omitted or not found.
    .EXAMPLE
        Dismount-TriageUserHives -Hives $global:TriageUserHives -ScratchFolder "$env:TEMP\TriageScratch"
    .INPUTS
        None.
    .OUTPUTS
        None.
    #>
    # $Hives is kept so existing calls still work
    [CmdletBinding()]
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
            Remove-Item -LiteralPath $ScratchFolder -Recurse -Force

            if (Test-Path -LiteralPath $ScratchFolder) {
                Show-Message -Message "Scratch folder could not be removed [ $ScratchFolder ]" `
                    -Level WARNING -AddToLog
            }
        }
    }
}


function Get-TriageBinary {
    <#
    .SYNOPSIS
        Returns the path of a trusted, hash-verified tool from the toolkit's bin folder.
    .DESCRIPTION
        Looks up Name in the "Binaries" section of the configuration, then checks that the matching
        executable was verified and registered in $global:TriageSys by Initialize-TriageSystemTools.
        Returns its full path so the caller can invoke it with the call operator. This prevents the
        toolkit from running a same-named program found elsewhere on the target computer.

        Throws a terminating error if Name is not defined in the configuration, or if the executable is
        missing from bin\ or failed its SHA256 check.
    .PARAMETER Name
        Key of the tool as defined in the "Binaries" section of TriageConfig.psd1, for example "reg",
        "robocopy" or "RawCopy". Not case-sensitive for the lookup of the verified file.
    .EXAMPLE
        & (Get-TriageBinary "reg") query "HKLM\SOFTWARE\Microsoft" /s
    .INPUTS
        None.
    .OUTPUTS
        System.String. Full path to the verified executable.
    #>
    [CmdletBinding()]
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
            throw "[ $Key.exe ] is missing from /bin/ folder or failed its hash check; refusing to run it."
        }

        $global:TriageSys[$Key]
    }
}

function Disable-PSReadLineHistory {
    <#
    .SYNOPSIS
        Turns off PSReadLine history saving for the current PowerShell session (best effort).
    .DESCRIPTION
        Sets the PSReadLine history save style to SaveNothing so that commands typed during the run are not
        written to the operator's ConsoleHost_history.txt, reducing the footprint left on the target. The
        result is logged as INFO, or as WARNING if the setting could not be changed.

        This only affects the current session. The command that launched the script has normally already
        been recorded by the time this runs; Write-LaunchContext documents the state of the history file
        so the examiner can account for it.
    .EXAMPLE
        Disable-PSReadLineHistory
    .INPUTS
        None.
    .OUTPUTS
        None.
    .NOTES
        If PSReadLine is not loaded (non-interactive launch) there is nothing to disable, and this is
        logged as such.
    #>
    [CmdletBinding()]
    param()
    try {
        if (Get-Module -Name PSReadLine) {
            Set-PSReadLineOption -HistorySaveStyle SaveNothing -ErrorAction Stop
            Show-Message -Message "PSReadLine history saving disabled for this session." `
                -Level INFO -AddToLog
        }
        else {
            Show-Message -Message "PSReadLine not loaded (non-interactive launch); nothing to disable." `
                -Level INFO -AddToLog
        }
    }
    catch {
        Show-Message -Message "Could not disable PSReadLine history => $( $_.Exception.Message )" `
            -Level WARNING -AddToLog
    }
}


function Write-LaunchContext {
    <#
    .SYNOPSIS
        Logs how the toolkit was launched and the state of the operator's PSReadLine history file.
    .DESCRIPTION
        Records, in the console and log file:
            - the full launch command line,
            - the PowerShell version, whether -NoProfile was used, and the operator's account,
            - a WARNING if -NoProfile was not used, because profile scripts on the target may have run,
            - the size and last-write time (UTC) of the history file, or a note that it does not exist.

        This lets an examiner later separate changes caused by the tool from the subject's own activity.
        Call it as early as possible, before Disable-PSReadLineHistory.

    .PARAMETER HistFile
        Path of the PSReadLine history file to report on. Defaults to the current user's
        %APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt.
    .EXAMPLE
        Write-LaunchContext
    .EXAMPLE
        Write-LaunchContext -HistFile
        "C:\Users\Operator\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    .INPUTS
        None.
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    param(
        [string]$HistFile = (
            Join-Path $env:APPDATA "Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
        )
    )
    begin {
        $ArgList = [Environment]::GetCommandLineArgs()
        $NoProf  = [bool]($ArgList | Where-Object { $_ -like "-NoProf*" })
    }
    process {
        Show-Message -Message "Launch command line => [ $( [Environment]::CommandLine ) ]" -Level INFO -AddToLog
        $Msg = "PowerShell $( $PSVersionTable.PSVersion ), -NoProfile used: $NoProf, operator account: `
            $env:USERDOMAIN\$env:USERNAME"
        Show-Message -Message $Msg -Level INFO -AddToLog

        if (-not $NoProf) {
            Show-Message -Message "Not launched with -NoProfile; target profile scripts may have run." `
                -Level WARNING -AddToLog
        }

        if (Test-Path -LiteralPath $HistFile) {
            $Item = Get-Item -LiteralPath $HistFile -Force
            Show-Message -Message "Operator PSReadLine history at start => [ $HistFile ], $( $Item.Length ) `
                bytes, last write (UTC) $( $Item.LastWriteTimeUtc.ToString('o') )" -Level INFO -AddToLog
        }
        else {
            Show-Message -Message "Operator PSReadLine history file not present at start." -Level INFO -AddToLog
        }
    }
}


function Initialize-TriageSystemTools {
    <#
    .SYNOPSIS
        Verifies the executables in the toolkit's bin folder against a trusted hash manifest.
    .DESCRIPTION
        Reads bin\__hashes.json and computes the SHA256 hash of every file listed. Files that are missing or
        whose hash does not match are logged as ERROR and are not trusted. Verified top-level .exe files
        are registered in $global:TriageSys (file name without extension -> full path), which is what
        Get-TriageBinary uses to decide whether a tool may be run. Files in subfolders and non-.exe files
        are verified but not registered.

        If the manifest is missing or unreadable, a message is logged and no tools are registered, so any
        later call to Get-TriageBinary will fail.

        A summary line (verified count, failed count and callable tool names) is logged at the end.
    .PARAMETER ToolkitRoot
        Root folder of the toolkit. The "bin" folder beneath it is checked.
    .EXAMPLE
        Initialize-TriageSystemTools -ToolkitRoot (Get-TriageConfig -Key "ToolkitRoot")
    .INPUTS
        None.
    .OUTPUTS
        None. Results are stored in $global:TriageSys.
    .NOTES
        The manifest is expected to contain a "Files" array of objects with "Path" (relative to bin) and
        "SHA256" properties.
    #>
    [CmdletBinding()]
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
            Show-Message -Message "Could not read $ManifestPath => $( $_.Exception.Message )" `
                -Level ERROR -AddToLog
            return
        }

        $Verified = 0
        $Failed   = 0
        foreach ($Entry in $Manifest.Files) {
            $Path = Join-Path -Path $Folder -ChildPath $Entry.Path

            if (-not (Test-Path -LiteralPath $Path)) {
                Show-Message -Message "Listed in manifest but missing => $( $Entry.Path )" `
                    -Level ERROR -AddToLog
                $Failed++
                continue
            }

            $Actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
            if ($Actual -ne $Entry.SHA256) {
                Show-Message -Message "Hash mismatch for $( $Entry.Path ) => binary is not trusted." `
                    -Level ERROR -AddToLog
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

        Show-Message -Message "Trusted tools => $Verified files verified, $Failed failed. `
            Callable => $( $global:TriageSys.Keys -join ', ' )" -Level INFO -AddToLog
    }
}


function Show-TriageBanner {
    <#
    .SYNOPSIS
        Displays the introduction banner when the application starts.
    .DESCRIPTION
        Prints the tool name, author and last-updated date (from the "Branding" section of the
        configuration), the purpose of the tool, and the operating instructions and warnings for the
        operator, including the instruction not to view the results on the target computer. The banner is
        shown without timestamps and is not written to the log.
    .EXAMPLE
        Show-TriageBanner
    .INPUTS
        None.
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
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
        Saves the operator and case details for this run to case_info.json.
    .DESCRIPTION
        Writes a JSON record containing the tool version, operator, agency, case number, computer name,
        account used to run the tool, start time (UTC, ISO 8601), local UTC offset, PowerShell version,
        launch command line, the options selected for the run, and a list of known changes the tool makes to
        the target (KnownTargetChanges).

        Run this before the results are hashed so that the file is covered by the hash manifest.
    .PARAMETER ResultsFolder
        The results folder for this run. case_info.json is created inside it.
    .PARAMETER Operator
        Name of the person running the collection.
    .PARAMETER CaseNumber
        Case number assigned to the investigation.
    .PARAMETER Selected
        Dictionary (hashtable or ordered dictionary) of the options and modules chosen for this run.
        Stored under "Options".
    .PARAMETER Agency
        Name of the investigating agency. Optional.
    .PARAMETER JsonFile
        Full path of the JSON file to create. Defaults to case_info.json inside ResultsFolder.
    .EXAMPLE
        Write-CaseInfo -ResultsFolder $global:ResultsFolder -Operator "MAS" -CaseNumber "12345"
        -Agency "Agency" -Selected ([ordered]@{ Modules = "all"; CaptureRam = "N" })
    .INPUTS
        None.
    .OUTPUTS
        None. The JSON file is written to disk.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsFolder,

        [Parameter(Mandatory)]
        [string]$Operator,

        [Parameter(Mandatory)]
        [string]$CaseNumber,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Selected,

        [string]$Agency,
        [string]$JsonFile = (Join-Path $ResultsFolder "case_info.json")
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
                "HKCU\Software\Sysinternals\PsInfo\EulaAccepted set for $env:USERDOMAIN\$env:USERNAME `
                (psinfo -accepteula)"
                "Typical execution artifacts (Prefetch, Amcache, ShimCache) for powershell.exe and each `
                tool run from bin\ (confirm on a lab VM)"
            )
        }
    }
    process {
        $Info | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $JsonFile -Encoding UTF8
    }
}


function Invoke-RegistryCommand {
    <#
    .SYNOPSIS
        Runs a registry-reading script block and logs missing keys or errors without stopping the run.
    .DESCRIPTION
        Executes Command with its error stream merged into the output, then separates the error records
        from the data:
            - "Path not found" errors are logged as INFO ("No data found for registry key [ ... ]"),
              since a key that does not exist is a normal finding.
            - Any other error (for example, access denied) is logged as ERROR.
        The data objects, without the errors, are returned to the caller. If nothing was found, the
        result is empty.
    .PARAMETER Command
        Script block containing the registry read, for example { Get-ItemProperty -Path "HKLM:\..." }.
    .EXAMPLE
        $Run = Invoke-RegistryCommand -Command {
            Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        }
    .INPUTS
        None.
    .OUTPUTS
        The objects emitted by Command, excluding error records.
    #>
    [CmdletBinding()]
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
                Show-Message -Message "Registry read problem [ $( $E.Exception.Message ) ]" `
                    -Level ERROR -AddToLog
            }
        }
        # Empty when nothing was found, so the caller sees $null
        $Data
    }
}


function Clear-TriageHives {
    <#
    .SYNOPSIS
        Unloads every TRIAGE_* registry hive, including ones left over from an interrupted run.
    .DESCRIPTION
        Forces garbage collection to release PowerShell's registry handles, then finds each key under
        HKEY_USERS whose name starts with "TRIAGE_" and unloads it with "reg unload". If an unload fails, the
        function waits two seconds, collects garbage again and retries once. Successes are logged as INFO.
        A hive that still cannot be unloaded is logged as ERROR with the manual command to run.

        Called at the start of Mount-TriageUserHives and by Dismount-TriageUserHives.
    .EXAMPLE
        Clear-TriageHives
    .INPUTS
        None.
    .OUTPUTS
        None.
    .NOTES
        Requires an elevated session and the trusted "reg" binary (see Get-TriageBinary).
    #>
    [CmdletBinding()]
    param()

    begin {
        # Release provider handles first
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
    }
    process {
        $Stale = @(
            Get-ChildItem -LiteralPath "Registry::HKEY_USERS" |
                Where-Object { $_.PSChildName -like "TRIAGE_*"
            }
        )

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
                Show-Message -Message "Could not unload hive $Name. Close other PowerShell windows and `
                    run: 'reg unload HKU\$Name'" -Level ERROR -AddToLog
            }
        }
    }
}


function Read-PowerShellDataFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $ResolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (-not (Test-Path -LiteralPath $ResolvedPath -PathType Leaf)) {
        throw "Data file not found: $ResolvedPath"
    }

    # Use native cmdlet if available
    if (Get-Command -Name Import-PowerShellDataFile -ErrorAction SilentlyContinue) {
        return Import-PowerShellDataFile -LiteralPath $ResolvedPath
    }

    # Fallback: Safely evaluate the .psd1 file content as a hashtable across any version
    try {
        $fileContent = Get-Content -LiteralPath $ResolvedPath -Raw -ErrorAction Stop
        # A standard .psd1 file contains a hashtable script block
        return [scriptblock]::Create($fileContent).Invoke()
    }
    catch {
        throw "Failed to parse PowerShell data file '$ResolvedPath': $_"
    }
}


function Import-TriageConfig {
    <#
    .SYNOPSIS
        Loads config\TriageConfig.psd1 into module scope. Private; do not export.
    .DESCRIPTION
        Reads the configuration data file from the toolkit and checks that the required top-level keys
        ("Modules", "Binaries", "Defaults") exist. Relative binary paths are converted to full paths under
        ToolkitRoot. The loaded configuration is then extended with ToolkitRoot, ConfigPath and ConfigSha256
        (the SHA256 hash of the config file, so the exact settings used can be recorded), and stored in
        $script:TriageConfig. $global:ToolkitRoot is also set for modules that have not yet been migrated to
        Get-TriageConfig.

        Throws a terminating error if the file is missing or a required key is absent.

        Other code should use Get-TriageConfig, which calls this function automatically on first use. This
        function must not be listed in the module manifest (triage.psd1).
    .PARAMETER ToolkitRoot
        Root folder of the toolkit. Defaults to the parent of the folder that contains this module file.
    .EXAMPLE
        Import-TriageConfig -ToolkitRoot "E:\WinTriageScript"
    .INPUTS
        None.
    .OUTPUTS
        None. The configuration is stored in $script:TriageConfig.
    #>
    [CmdletBinding()]
    param(
        [string]$ToolkitRoot = (Split-Path -Path $PSScriptRoot -Parent)
    )

    $Path = Join-Path -Path $ToolkitRoot -ChildPath "config\TriageConfig.psd1"
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Configuration file not found => [ $Path ]"
    }

    $Cfg = Read-PowerShellDataFile -Path $Path

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
        Returns a setting (or the whole configuration) from TriageConfig.psd1.
    .DESCRIPTION
        Returns the value stored under Key in the loaded configuration. If Key is omitted, the entire
        configuration hashtable is returned. If the configuration has not been loaded yet, it is loaded
        first with Import-TriageConfig.
    .PARAMETER Key
        Name of the configuration entry, for example "Modules", "Binaries", "Defaults", "Branding" or
        "ToolkitRoot". Omit to return everything.
    .EXAMPLE
        Get-TriageConfig -Key "ToolkitRoot"
    .EXAMPLE
        (Get-TriageConfig).ConfigSha256
    .INPUTS
        None.
    .OUTPUTS
        The requested value (type depends on the key), or System.Collections.Hashtable for the full
        configuration.
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
        Converts a TimeSpan into short, readable text for console and log messages.
    .DESCRIPTION
        Output depends on the length of the span (invariant culture is always used):
            under 1 minute   "12.34 seconds"
            under 1 hour     "5 min 07 sec"
            1 hour or more   "2 hr 05 min 09 sec"
    .PARAMETER Span
        The elapsed time to format, for example the Elapsed value of a Stopwatch.
    .EXAMPLE
        Format-TriageDuration -Span (New-TimeSpan -Seconds 75)
        Returns "1 min 15 sec".
    .INPUTS
        None.
    .OUTPUTS
        System.String.
    #>
    [CmdletBinding()]
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

        [string]::Format(
            $Inv, "{0} hr {1:00} min {2:00} sec", `
            [int][math]::Floor($Span.TotalHours), $Span.Minutes, $Span.Seconds
        )
    }
}


function Invoke-TriageTask {
    <#
    .SYNOPSIS
        Runs one collection task with timing, error handling and output verification.
    .DESCRIPTION
        Standard wrapper for a unit of work. It:
          1. Logs Message as INFO.
          2. Runs Action inside a try/catch and discards its output. An exception is logged as ERROR and
             the task is marked "Failed".
          3. Stops the timer and formats the elapsed time.
          4. If the action did not throw, checks each path in ExpectedFile (wildcards allowed) for at least
             one non-empty file, then sets the status:
                 MissingOutput        an expected file is missing or empty (logged as ERROR)
                 CompletedWithErrors  errors were logged during the task (logged as WARNING)
                 OK                   success; the output files and time are logged as SUCCESS
          5. Adds a record (StartedUtc, Task, Seconds, Status) to $global:TriageTimings when that
             collection exists.

        Errors are detected by comparing $global:TriageErrorCount before and after the task, so any
        Show-Message call at ERROR level during the task counts.
    .PARAMETER Message
        Description of the task. Shown to the operator, logged, and stored as the task name in the timings.
    .PARAMETER Action
        Script block that performs the work.
    .PARAMETER ExpectedFile
        Full paths of the files the task should create. Wildcards are allowed. Optional; when omitted,
        no output check is made.
    .EXAMPLE
        Invoke-TriageTask -Message "Collecting services" -ExpectedFile "$global:ResultsFolder\services.csv" -Action {
            Write-OutputToCsv -Data (Get-CimInstance Win32_Service) -OutputFile "$global:ResultsFolder\services.csv"
        }
    .INPUTS
        None.
    .OUTPUTS
        None.
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
        Show-Message -Message "Execution failed during [ $Action ] => $( $_.Exception.Message )" `
            -Level ERROR -AddToLog
    }

    $Sw.Stop()
    $Time = Format-TriageDuration -Span $Sw.Elapsed

    $Present = [System.Collections.Generic.List[string]]::new()
    $Missing = [System.Collections.Generic.List[string]]::new()
    if ($Status -eq "OK") {
        foreach ($Path in $ExpectedFile) {
            $Hits = if ($Path -match "[\*\?]") {
                    @(Get-ChildItem -Path $Path -File -Force )
                }
                else {
                    @(Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
                        Where-Object { $_ -is [System.IO.FileInfo] })
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
            Show-Message -Message "[ $Message ] finished ($Time) but expected output is missing or empty => `
            $( ($Missing |
            ForEach-Object { Split-Path -Path $_ -Leaf }) -join ', ' )" -Level ERROR -AddToLog
        }
        elseif ($NewErrors -gt 0) {
            $Status = "CompletedWithErrors"
            Show-Message -Message "[ $Message ] completed with $NewErrors error(s) ($Time). `
            See application log." -Level WARNING -AddToLog
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
        Runs a list of task definitions through Invoke-TriageTask.
    .DESCRIPTION
        For each task, the file names in its Files property are combined with Folder to form the expected
        output paths, and the task is run with Invoke-TriageTask. Tasks run one after another in the order
        given.

        Each task object must have:
            Message   Description shown and logged.
            Action    Script block that does the work.
            Files     Array of file names (relative to Folder) the task should create. May be empty.
    .PARAMETER Tasks
        Array of task objects or hashtables with the Message, Action and Files properties.
    .PARAMETER Folder
        Folder in which the expected output files are located.
    .EXAMPLE
        $Tasks = @(
            @{ Message = "Collecting services"; Files = @("services.csv"); Action = { Get-ServiceData } }
            @{ Message = "Collecting drivers";  Files = @("drivers.csv");  Action = { Get-DriverData } }
        )
        Invoke-TriageTaskList -Tasks $Tasks -Folder "$global:ResultsFolder\System"
    .INPUTS
        None.
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Tasks,

        [Parameter(Mandatory)]
        [string]$Folder
    )

    foreach ($Task in $Tasks) {
        $Expected = @(
            $Task.Files |
            Where-Object { $_ } |
            ForEach-Object {
                Join-Path -Path $Folder -ChildPath $_
            }
        )
        Invoke-TriageTask -Message $Task.Message -Action $Task.Action -ExpectedFile $Expected
    }
}


function New-TriageCopyResult {
    <#
    .SYNOPSIS
        Creates a blank result record for a file or folder copy operation.
    .DESCRIPTION
        Returns a PSCustomObject with Status preset to "Failed" and the other fields empty. The copy
        functions fill it in as they work, so that every attempt, successful or not, produces the same
        kind of record for the collection log.

        Properties: Source, Destination, Method, Status, SizeBytes, SourceCreatedUtc, SourceModifiedUtc,
        SourceAccessedUtc, Detail.
    .PARAMETER Source
        Path (or registry key) being copied.
    .PARAMETER Destination
        Path to which it is being copied.
    .EXAMPLE
        $R = New-TriageCopyResult -Source "C:\Windows\System32\config\SAM" -Destination "$global:ResultsFolder\SAM"
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    #>
    [CmdletBinding()]
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
        Copies a file by reading it directly from the volume with the trusted RawCopy tool.
    .DESCRIPTION
        Used for files that Windows keeps locked or hides from normal file APIs. Creates the destination
        folder if needed and runs RawCopy (verified by Get-TriageBinary) hidden and waiting for it to finish.
        RawCopy's working directory is the destination folder, so any log file it writes lands beside the
        output.

        Throws a terminating error if the tool is not trusted or if no non-empty output file was produced.
    .PARAMETER Source
        Full path of the file to copy. RawCopy also accepts NTFS metadata paths such as "C:\$MFT".
    .PARAMETER Destination
        Full path of the file to create, including the file name.
    .EXAMPLE
        Invoke-TriageRawCopy -Source "C:\Windows\System32\config\SYSTEM" -Destination "$global:ResultsFolder\Registry\SYSTEM"
    .INPUTS
        None.
    .OUTPUTS
        None.
    .NOTES
        Requires an elevated session.
    #>
    [CmdletBinding()]
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
    $null = Start-Process -FilePath $Exe -ArgumentList $ArgList -WorkingDirectory $Dir -Wait -PassThru `
        -WindowStyle Hidden

    $Out = Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    if (-not $Out -or $Out.Length -eq 0) {
        throw "RawCopy produced no output for [ $Source ]."
    }
}


function Copy-TriageFile {
    <#
    .SYNOPSIS
        Copies a file for collection, falling back to a raw volume read if the file is locked.
    .DESCRIPTION
        1. Reads the source file's size and created, modified and accessed times (UTC) before touching
           it. Returns Status "NotFound" if the source does not exist.
        2. Tries a normal copy that opens the source with read/write/delete sharing (Method "SharedRead").
           On success, the destination's last-write time is set to match the source.
        3. If that fails (for example, an exclusive lock), removes the partial copy and tries
           Invoke-TriageRawCopy (Method "RawCopy").
        4. If both fail, Status is "Locked" and Detail contains both error messages.

        The record returned always contains the source's timestamps so they are preserved even where the
        copy's own timestamps differ.
    .PARAMETER Source
        Full path of the file to copy.
    .PARAMETER Destination
        Full path of the file to create, including the file name. The folder is created if needed.
    .EXAMPLE
        $Result = Copy-TriageFile -Source "C:\Windows\appcompat\Programs\Amcache.hve" `
            -Destination "$global:ResultsFolder\Amcache\Amcache.hve"
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject (see New-TriageCopyResult). Status is OK, NotFound
        or Locked.
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
    catch {
        $R.Detail = $_.Exception.Message
    }
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
        Copies a file using RawCopy only, with no normal-copy attempt.
    .DESCRIPTION
        For items that can only be read from the volume, such as the $MFT and $UsnJrnl. Calls
        Invoke-TriageRawCopy and returns a result record with Method "RawCopy", Status "OK" or "Failed",
        the output size, and the error message in Detail if it failed. Source timestamps are not recorded
        because these are NTFS metadata files.
    .PARAMETER Source
        Path of the item to copy, for example "C:\$MFT".
    .PARAMETER Destination
        Full path of the file to create, including the file name.
    .EXAMPLE
        Copy-TriageRawFile -Source 'C:\$MFT' -Destination "$global:ResultsFolder\NTFS\MFT"
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject (see New-TriageCopyResult).
    .NOTES
        Requires an elevated session.
    #>
    [CmdletBinding()]
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
        Exports a loaded registry hive to a file with "reg save".
    .DESCRIPTION
        Runs the trusted reg.exe (see Get-TriageBinary) to write a consolidated copy of the hive, such as
        HKLM\SYSTEM, to Destination, overwriting any existing file. The result is OK only if reg.exe
        returns exit code 0 and the file exists; otherwise Status is "Failed" and Detail holds the
        tool's output or the exception message.
    .PARAMETER HiveKey
        Registry key to save, in reg.exe syntax, for example "HKLM\SYSTEM".
    .PARAMETER Destination
        Full path of the file to create. The folder is created if needed.
    .EXAMPLE
        Save-TriageRegistryHive -HiveKey "HKLM\SYSTEM" -Destination "$global:ResultsFolder\Registry\SYSTEM.regsave"
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject (see New-TriageCopyResult). Method is "reg save".
    .NOTES
        Requires an elevated session.
    #>
    # reg save: a consolidated export of a loaded hive
    [CmdletBinding()]
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
        Copies a folder tree using robocopy in backup mode.
    .DESCRIPTION
        Runs the trusted robocopy.exe with /E /B /XJ /COPY:DAT /DCOPY:DAT /R:0 /W:0 so that:
            - subfolders (including empty ones) are copied,
            - backup mode reads folders whose ACL excludes administrators,
            - junctions are not followed,
            - data, attributes and timestamps are preserved,
            - locked files are skipped immediately rather than retried.

        Robocopy exit codes of 8 or higher are treated as failures (Status "Failed"; Detail holds the exit
        code and output). Otherwise the destination is scanned: Status is "OK" if at least one file was
        copied, or "NotFound" if nothing was copied. SizeBytes is the total size of the copied files.
    .PARAMETER Source
        Full path of the folder to copy.
    .PARAMETER Destination
        Full path of the folder in which the copy is created.
    .EXAMPLE
        Copy-TriageFolderBackup -Source "C:\Windows\Prefetch" -Destination "$global:ResultsFolder\Prefetch"
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject (see New-TriageCopyResult). Method is "robocopy /B".
    .NOTES
        Requires an elevated session.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $R = New-TriageCopyResult -Source $Source -Destination $Destination
    $R.Method = "robocopy /B"
    try {
        $Raw = & (Get-TriageBinary "robocopy") $Source $Destination `
            /E /B /XJ /COPY:DAT /DCOPY:DAT /R:0 /W:0 /NP /NJH /NJS /NDL /NC /NS 2>&1

        if ($LASTEXITCODE -ge 8) {
            $R.Detail = "robocopy exit $LASTEXITCODE => $( ($Raw | ForEach-Object { "$_" }) -join ' ' )"
        }
        else {
            $Files = @(Get-ChildItem -LiteralPath $Destination -Recurse -File -Force)
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
