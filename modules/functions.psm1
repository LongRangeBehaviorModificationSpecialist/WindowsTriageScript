# Date Last Updated
$Dlu = "18-Jun-2026"

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

$run_date = Get-Date -Format yyyyMMdd_HHmmss
$ComputerName = $env:computername
$ipv4 = (Test-Connection $ComputerName -TimeToLive 2 -Count 1).ipv4address | Select-Object -ExpandProperty IPAddressToString

$merged_name = $run_date + "_" + $ipv4 + "_" + $ComputerName

$ResultsFolder = Join-Path -Path $(Get-Location) -ChildPath "$($run_date + "_" + $ipv4 + "_" + $ComputerName)"
$null = New-Item -ItemType Directory -Path $ResultsFolder -Force

$LogFolder = Join-Path -Path $ResultsFolder -ChildPath "Logs"
$null = New-Item -ItemType Directory -Path $LogFolder -Force

$Log_file = Join-Path -Path $LogFolder -ChildPath "$($merged_name)_Script.log"
$null = New-Item -ItemType File -Path $Log_file -Force


# =============================
#
# NEW FUNCTIONS
#
# =============================

function Invoke-TriageTranscript {

    try {
        # Start transcript to record all of the screen output
        $transcript_begin_msg = "Powershell Transcript started..."
        Start-Transcript -OutputDirectory $LogFolder -IncludeInvocationHeader -NoClobber
        Show-MessageAndWriteLogEntry -Msg $transcript_begin_msg -Level INFO
    }
    catch {
        $ErrorMsg = "Failed to start Powershell Transcript: $( $_.Exception.Message )"
        Show-MessageAndWriteLogEntry -Msg $ErrorMsg -Level ERROR
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
        $is_admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($is_admin) {
            $is_admin_msg = "DFIR Session starting as Administrator..."
            Show-MessageAndWriteLogEntry -Msg $is_admin_msg -Level INFO
        }
        else {
            $non_admin_msg = "No Administrator session detected. For the best performance run as Administrator. Not all items can be collected. DFIR Session starting..."
            Show-MessageAndWriteLogEntry -Msg $non_admin_msg -Level INFO
        }
    }
    catch {
        $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error: $( $_.Exception.Message )"
        Show-MessageAndWriteLogEntry -Msg $ErrorMsg -Level ERROR
    }
}


function Show-Message {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$msg,

        [Parameter(Mandatory = $false)]
        [System.ConsoleColor]$text_color,

        [switch]$no_time
    )

    # Generate timestamp if -NoTime is not provided
    $timestamp = if (-not $no_time) { $(Get-Date -Format "[yyyy-MM-dd HH:mm:ss.fff] ") } else { "" }

    $host_args = @{ Object = "$timestamp$msg" }

    if ($PSBoundParameters.ContainsKey("TextColor")) {
        $host_args["ForegroundColor"] = $text_color
    }

    Write-Host @host_args
}


function Show-MessageAndWriteLogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$msg,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO","WARNING","ERROR","SUCCESS")]
        [string]$level = "INFO",

        [Parameter(Mandatory = $false)]
        [string]$ExecutionTime,

        [Parameter(Mandatory = $false)]
        [string]$File
    )

    begin {
        $timestamp = $(Get-Date -Format "[yyyy-MM-dd HH:mm:ss.fff]")

        # Format of the line to write to the log file
        $Entry_prefix = "$timestamp [$level] "
    }
    process {
        try {
            if ($level -eq "SUCCESS") {
                $msg = "Process completed successfully. Output saved to -> `"$([System.IO.Path]::GetFileName($File))`""
                if ($ExecutionTime) {
                    $msg += " (completed in $($ExecutionTime))."
                }
            }

            $full_message = "$Entry_prefix$msg"

            switch ($level) {
                "SUCCESS" { Write-Host "$($full_message)" -ForegroundColor Green }
                "WARNING" { Write-Host "$($full_message)" -ForegroundColor Yellow }
                "ERROR"   { Write-Error "$($full_message)" -ErrorAction Continue }
                default   { Write-Host "$($full_message)" -ForegroundColor White }
            }

            "$full_message" | Out-File -FilePath $Log_file -Append -Encoding utf8 -NoClobber
        }
        catch {
            # If writing to the USB log fails, we MUST flash it to the screen so the examiner knows.
            Write-Host "CRITICAL: Unable to write to triage log file! Error: $( $_.Exception.Message )" -ForegroundColor Red
        }
    }
}

function Write-LogMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$msg
    )

    process {
        if (-not $msg) {
            Write-Error -Msg "The `"-message`" parameter cannot be empty."
            return
        }

        $timestamp = $(Get-Date -Format "[yyyy-MM-dd HH:mm:ss.fff] ")
        "$timestamp$msg" | Out-File -FilePath $Log_file -Append -Encoding UTF8
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
        $Command_string = "Command: $($Command.ToString())`n`n"
    }
    process {
        if (-not $Data) {
            "$($Command_string) No data found when running this function." | Out-File -FilePath $OutputFile
        }
        else {
            if (-not $Append) {
                $Command_string | Out-File -FilePath $OutputFile -Encoding utf8
            }
            else {
                $Command_string | Out-File -FilePath $OutputFile -Encoding utf8 -Append
            }
            $Data | Out-File -FilePath $OutputFile -Encoding utf8 -Append
        }
    }
}

function Test-IfExists {
    param(
        [string]$FolderName,
        [string]$File_name,
        [ValidateSet("FOLDER","FILE")]
        [string]$type
    )

    if ($type -eq "FOLDER") {
        $FolderName_text = $(Split-Path -Path $FolderName -Leaf)
        if (Test-Path $FolderName) {
            $Folder_created_msg = "---- `"$($FolderName_text)`" ---- sub-directory created successfully."
            Show-MessageAndWriteLogEntry -Msg $Folder_created_msg -Level INFO
        }
        else {
            Show-MessageAndWriteLogEntry -Msg "The necessary sub-directory does not exist or could not be created -> `"$($FolderName_text)`"" -Level ERROR
            return
        }
    }
    if ($type -eq "FILE") {
        $File_name_text = $(Split-Path -Path $File_name -Leaf)
        if (Test-Path $File_name) {
            $File_created_msg = "The `"$($File_name_text)`" file was created successfully."
            Show-MessageAndWriteLogEntry -Msg $File_created_msg -Level INFO
        }
        else {
            Show-MessageAndWriteLogEntry -Msg "There was an error creating the `"$($File_name_text)`" file." -Level ERROR
            return
        }
    }
}
