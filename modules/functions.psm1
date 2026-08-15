# Date Last Updated
$Dlu = "15-Aug-2026"

# List of file types to use in some commands
$ExecutableFileTypes = @(
    "*.BAT", "*.BIN", "*.CGI", "*.CMD", "*.COM", "*.DLL", "*.EXE", "*.JAR",
    "*.JOB", "*.JSE", "*.MSI", "*.PAF", "*.PS1", "*.SCR", "*.SCRIPT",
    "*.VB", "*.VBE", "*.VBS", "*.VBSCRIPT", "*.WS", "*.WSF"
)

$StartTime = Get-Date

$Binaries = @{
    "MagnetRamCapture"     = ".\bin\MagnetRAMCapture.exe"
    "MagnetProcessCapture" = ".\bin\MagnetProcessCapture.exe"
    "PSInfo"               = ".\bin\PsInfo.exe"
    "SQLite3"              = ".\bin\sqlite3.exe"
    "EDD"                  = ".\bin\EDDv310.exe"
}

function Get-InitialSetup{
    param()

    $RunDate = Get-Date -Format yyyyMMdd_HHmmss
    $ComputerName = $env:computername
    $Ipv4 = (Test-Connection $ComputerName -TimeToLive 2 -Count 1).ipv4address | Select-Object -ExpandProperty IPAddressToString

    $MergedName = $RunDate + "_" + $Ipv4 + "_" + $ComputerName

    $global:ResultsFolder = Join-Path -Path $(Get-Location) -ChildPath "$($RunDate + "_" + $Ipv4 + "_" + $ComputerName)"
    $null                 = New-Item -ItemType Directory -Path $ResultsFolder -Force

    $LogFolder = Join-Path -Path $ResultsFolder -ChildPath "Logs"
    $null      = New-Item -ItemType Directory -Path $LogFolder -Force

    $global:LogFile = Join-Path -Path $LogFolder -ChildPath "$($MergedName)_Script.log"
    $null           = New-Item -ItemType File -Path $LogFile -Force
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
        [Parameter(Mandatory)]
        [object]$Data,

        [Parameter(Mandatory = $true)]
        [string]$OutputFile
    )

    process {
        $Data | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
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

        [switch]$AddToLog
    )

    try {
        # Handle SUCCESS auto-message
        if ($Level -eq "SUCCESS") {
            $Message = "Process completed successfully. Output saved to -> '$( [System.IO.Path]::GetFileName($File) )'"
            if ($ExecutionTime) {
                $Message += " (completed in $ExecutionTime)."
            }
        }

        # Build timestamp string only (no color attached yet)
        if ($NoTime) {
            $Timestamp = ""
        }
        else {
            $Timestamp = Get-Date -Format "dd-MMM-yyyy HHmmss.fff"
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
        else {
            Write-Host "[$Timestamp] " -ForegroundColor $TimestampColor -NoNewLine
            Write-Host $Message -ForegroundColor $DisplayColor
        }

        # LOG TO FILE (if requested)
        if ($AddToLog -and $LogFile) {
            try {
                $LogMessage | Out-File -FilePath $LogFile -Append -Encoding utf8 -NoClobber
            }
            catch {
                # If writing to the USB log fails, tell the examiner
                Write-Host "CRITICAL: Unable to write to triage log file! Error: $( $_.Exception.Message )" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Error "An uncaught error occured. Error -> $( $_.Exception.Message )"
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

        $Timestamp = Get-Date -Format "MMddyy HHmmss.fff"
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
            "$CommandString No data found when running this function." |
                Out-File -FilePath $OutputFile
        }
        else {
            if (-not $Append) {
                $CommandString | Out-File -FilePath $OutputFile -Encoding utf8
            }
            else {
                $CommandString | Out-File -FilePath $OutputFile -Encoding utf8 -Append
            }
            $Data | Out-File -FilePath $OutputFile -Encoding utf8 -Append
        }
    }
}

function Read-LogHost {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Prompt,

        [ConsoleColor]$TimeStampColor = 'Cyan',
        [ConsoleColor]$PromptColor = 'Gray',

        # Pass through standard Read-Host parameters
        [switch]$AsSecureString
    )

    $Timestamp = Get-Date -Format 'dd-MMM-yyyy HHmmss.fff'

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
        [ValidateSet("FOLDER","FILE")]

        [string]$Type
    )

    if ($Type -eq "FOLDER") {
        $FolderNameText = $(Split-Path -Path $FolderName -Leaf)
        if (Test-Path $FolderName) {
            $FolderCreatedMsg = "'$FolderNameText' sub-directory created successfully."
            Show-Message -Message $FolderCreatedMsg -Level INFO -AddToLog
        }
        else {
            Show-Message -Message "The necessary sub-directory does not exist `
                or could not be created -> '$FolderNameText'" -Level ERROR -AddToLog
            return
        }
    }
    if ($Type -eq "FILE") {
        $FileNameText = $(Split-Path -Path $FileName -Leaf)
        if (Test-Path $FileName) {
            $FileCreatedMsg = "The '$FileNameText' file was created successfully."
            Show-Message -Message $FileCreatedMsg -Level INFO -AddToLog
        }
        else {
            Show-Message -Message "There was an error creating the '$($FileNameText)' file." -Level ERROR -AddToLog
            return
        }
    }
}
