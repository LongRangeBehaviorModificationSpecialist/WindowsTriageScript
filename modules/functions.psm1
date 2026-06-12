# $ModuleName = Split-Path -Path $PSCommandPath

# Date Last Updated
$dlu = "27-May-2026"

# List of file types to use in some commands
$executableFileTypes = @(
    "*.BAT", "*.BIN", "*.CGI", "*.CMD", "*.COM", "*.DLL", "*.EXE", "*.JAR",
    "*.JOB", "*.JSE", "*.MSI", "*.PAF", "*.PS1", "*.SCR", "*.SCRIPT",
    "*.VB", "*.VBE", "*.VBS", "*.VBSCRIPT", "*.WS", "*.WSF"
)

$startTime = Get-Date

$binaries = @{
    "MagnetRamCapture"     = ".\bin\MagnetRAMCapture.exe"
    "MagnetProcessCapture" = ".\bin\MagnetProcessCapture.exe"
    "PSInfo"               = ".\bin\PsInfo.exe"
    "SQLite3"              = ".\bin\sqlite3.exe"
    "EDD"                  = ".\bin\EDDv310.exe"
}

$runDate = Get-Date -Format yyyyMMdd_HHmmss
$computerName = $env:computername
$ipv4 = (Test-Connection $computerName -TimeToLive 2 -Count 1).ipv4address | Select-Object -ExpandProperty IPAddressToString

$mergedName = $runDate + "_" + $ipv4 + "_" + $computerName

$resultsFolder = Join-Path -Path $(Get-Location) -ChildPath "$($runDate + "_" + $ipv4 + "_" + $computerName)"
$null = New-Item -ItemType Directory -Path $resultsFolder -Force

$logFolder = Join-Path -Path $resultsFolder -ChildPath "Logs"
$null = New-Item -ItemType Directory -Path $logFolder -Force

$logFile = Join-Path -Path $logFolder -ChildPath "$($mergedName)_Script.log"
$null = New-Item -ItemType File -Path $logFile -Force


# =============================
#
# NEW FUNCTIONS
#
# =============================

function Invoke-TriageTranscript {

    try {
        # Start transcript to record all of the screen output
        $transcriptBeginMessage = "Powershell Transcript started..."
        Start-Transcript -OutputDirectory $logFolder -IncludeInvocationHeader -NoClobber
        Show-MessageAndWriteLogEntry -Message $transcriptBeginMessage -Level INFO
    }
    catch {
        $errorMessage = "Failed to start Powershell Transcript: $($_.Exception.Message)"
        Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
    }
}


function Save-OutputAsCsv {
    param(
        [Parameter(Mandatory)]
        [object]$data,

        [Parameter(Mandatory = $true)]
        [string]$outputFile
    )

    process {
        $data | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
    }
}

function Show-IsAdmin {

    try {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($isAdmin) {
            $isAdminMessage = "DFIR Session starting as Administrator..."
            Show-MessageAndWriteLogEntry -Message $isAdminMessage -Level INFO
        }
        else {
            $nonAdminMessage = "No Administrator session detected. For the best performance run as Administrator. Not all items can be collected. DFIR Session starting..."
            Show-MessageAndWriteLogEntry -Message $nonAdminMessage -Level INFO
        }
    }
    catch {
        $errorMessage = "Execution failed during '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
        Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
    }
}


function Show-Message {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$message,

        [Parameter(Mandatory = $false)]
        [System.ConsoleColor]$textColor,

        [switch]$noTime
    )

    # Generate timestamp if -NoTime is not provided
    $timestamp = if (-not $noTime) { $(Get-Date -Format "[yyyy-MM-dd HH:mm:ss.fff] ") } else { "" }

    $hostArgs = @{ Object = "$timestamp$message" }

    if ($PSBoundParameters.ContainsKey("TextColor")) {
        $hostArgs["ForegroundColor"] = $textColor
    }

    Write-Host @hostArgs
}


function Show-MessageAndWriteLogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO","WARNING","ERROR","SUCCESS")]
        [string]$level = "INFO",

        [Parameter(Mandatory = $false)]
        [string]$executionTime,

        [Parameter(Mandatory = $false)]
        [string]$file
    )

    begin {
        $timestamp = $(Get-Date -Format "[yyyy-MM-dd HH:mm:ss.fff]")

        # Format of the line to write to the log file
        $entryPrefix = "$timestamp [$level] "
    }
    process {
        try {
            if ($level -eq "SUCCESS") {
                $message = "Process completed successfully. Output saved to -> '$([System.IO.Path]::GetFileName($file))'"
                if ($executionTime) {
                    $message += " (completed in $executionTime)."
                }
            }

            $fullMessage = "$entryPrefix$message"

            switch ($level) {
                "SUCCESS" { Write-Host "$fullMessage" -ForegroundColor Green }
                "WARNING" { Write-Host "$fullMessage" -ForegroundColor Yellow }
                "ERROR" { Write-Error "$fullMessage" -ErrorAction Continue }
                default { Write-Host "$fullMessage" -ForegroundColor White }
            }

            "$fullMessage" | Out-File -FilePath $logFile -Append -Encoding utf8 -NoClobber
        }
        catch {
            # If writing to the USB log fails, we MUST flash it to the screen so the examiner knows.
            Write-Host "CRITICAL: Unable to write to triage log file! Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Write-LogMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$message
    )

    process {
        if (-not $message) {
            Write-Error -Message "The `"-message`" parameter cannot be empty."
            return
        }

        $timestamp = $(Get-Date -Format "[yyyy-MM-dd HH:mm:ss.fff] ")
        "$timestamp$message" | Out-File -FilePath $logFile -Append -Encoding UTF8
    }
}

function Write-OutputToFile {
    # Writes the results of the commands to the $outputFile

    param(
        [Parameter(Mandatory = $false)]
        [string]$command,

        [Parameter(Mandatory = $false)]
        [System.Object]$data,

        [Parameter(Mandatory = $true)]
        [string]$outputFile,

        [switch]$append
    )

    begin {
        $commandString = "Command: $($command.ToString())`n`n"
    }
    process {
        if (-not $data) {
            "$commandString No data found when running this function." | Out-File -FilePath $outputFile
        }
        else {
            if (-not $append) {
                $commandString | Out-File -FilePath $outputFile -Encoding utf8
            }
            else {
                $commandString | Out-File -FilePath $outputFile -Encoding utf8 -Append
            }
            $data | Out-File -FilePath $outputFile -Encoding utf8 -Append
        }
    }
}

function Test-IfExists {
    param(
        [string]$folderName,
        [string]$fileName,
        [ValidateSet("FOLDER","FILE")]
        [string]$type
    )

    if ($type -eq "FOLDER") {
        $folderNameText = $(Split-Path -Path $folderName -Leaf)
        if (Test-Path $folderName) {
            $folderCreatedMsg = "---- '$folderNameText' ---- sub-directory created successfully."
            Show-MessageAndWriteLogEntry -Message $folderCreatedMsg -Level INFO
        }
        else {
            Show-MessageAndWriteLogEntry -Message "The necessary sub-directory does not exist or could not be created -> '$folderNameText'" -Level ERROR
            return
        }
    }
    if ($type -eq "FILE") {
        $fileNameText = $(Split-Path -Path $fileName -Leaf)
        if (Test-Path $fileName) {
            $fileCreatedMsg = "The '$fileNameText' file was created successfully."
            Show-MessageAndWriteLogEntry -Message $fileCreatedMsg -Level INFO
        }
        else {
            Show-MessageAndWriteLogEntry -Message "There was an error creating the '$fileNameText' file." -Level ERROR
            return
        }
    }
}
