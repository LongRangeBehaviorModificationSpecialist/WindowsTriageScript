# Date Last Updated
$dlu = "18-Jun-2026"

# List of file types to use in some commands
$executable_file_types = @(
    "*.BAT", "*.BIN", "*.CGI", "*.CMD", "*.COM", "*.DLL", "*.EXE", "*.JAR",
    "*.JOB", "*.JSE", "*.MSI", "*.PAF", "*.PS1", "*.SCR", "*.SCRIPT",
    "*.VB", "*.VBE", "*.VBS", "*.VBSCRIPT", "*.WS", "*.WSF"
)

$start_time = Get-Date

$binaries = @{
    "MagnetRamCapture"     = ".\bin\MagnetRAMCapture.exe"
    "MagnetProcessCapture" = ".\bin\MagnetProcessCapture.exe"
    "PSInfo"               = ".\bin\PsInfo.exe"
    "SQLite3"              = ".\bin\sqlite3.exe"
    "EDD"                  = ".\bin\EDDv310.exe"
}

$run_date = Get-Date -Format yyyyMMdd_HHmmss
$computer_name = $env:computername
$ipv4 = (Test-Connection $computer_name -TimeToLive 2 -Count 1).ipv4address | Select-Object -ExpandProperty IPAddressToString

$merged_name = $run_date + "_" + $ipv4 + "_" + $computer_name

$results_folder = Join-Path -Path $(Get-Location) -ChildPath "$($run_date + "_" + $ipv4 + "_" + $computer_name)"
$null = New-Item -ItemType Directory -Path $results_folder -Force

$log_folder = Join-Path -Path $results_folder -ChildPath "Logs"
$null = New-Item -ItemType Directory -Path $log_folder -Force

$log_file = Join-Path -Path $log_folder -ChildPath "$($merged_name)_Script.log"
$null = New-Item -ItemType File -Path $log_file -Force


# =============================
#
# NEW FUNCTIONS
#
# =============================

function Invoke-TriageTranscript {

    try {
        # Start transcript to record all of the screen output
        $transcript_begin_msg = "Powershell Transcript started..."
        Start-Transcript -OutputDirectory $log_folder -IncludeInvocationHeader -NoClobber
        Show-MessageAndWriteLogEntry -Msg $transcript_begin_msg -Level INFO
    }
    catch {
        $error_msg = "Failed to start Powershell Transcript: $($_.Exception.Message)"
        Show-MessageAndWriteLogEntry -Msg $error_msg -Level ERROR
    }
}


function Write-OutputToCsv {
    param(
        [Parameter(Mandatory)]
        [object]$data,

        [Parameter(Mandatory = $true)]
        [string]$output_file
    )

    process {
        $data | Export-Csv -Path $output_file -NoTypeInformation -Encoding UTF8
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
        $error_msg = "Execution failed during `"$($MyInvocation.MyCommand.Name)`". Error: $($_.Exception.Message)"
        Show-MessageAndWriteLogEntry -Msg $error_msg -Level ERROR
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
        [string]$execution_time,

        [Parameter(Mandatory = $false)]
        [string]$file
    )

    begin {
        $timestamp = $(Get-Date -Format "[yyyy-MM-dd HH:mm:ss.fff]")

        # Format of the line to write to the log file
        $entry_prefix = "$timestamp [$level] "
    }
    process {
        try {
            if ($level -eq "SUCCESS") {
                $msg = "Process completed successfully. Output saved to -> `"$([System.IO.Path]::GetFileName($file))`""
                if ($execution_time) {
                    $msg += " (completed in $($execution_time))."
                }
            }

            $full_message = "$entry_prefix$msg"

            switch ($level) {
                "SUCCESS" { Write-Host "$($full_message)" -ForegroundColor Green }
                "WARNING" { Write-Host "$($full_message)" -ForegroundColor Yellow }
                "ERROR"   { Write-Error "$($full_message)" -ErrorAction Continue }
                default   { Write-Host "$($full_message)" -ForegroundColor White }
            }

            "$full_message" | Out-File -FilePath $log_file -Append -Encoding utf8 -NoClobber
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
        [string]$msg
    )

    process {
        if (-not $msg) {
            Write-Error -Msg "The `"-message`" parameter cannot be empty."
            return
        }

        $timestamp = $(Get-Date -Format "[yyyy-MM-dd HH:mm:ss.fff] ")
        "$timestamp$msg" | Out-File -FilePath $log_file -Append -Encoding UTF8
    }
}

function Write-OutputToFile {
    # Writes the results of the commands to the $output_file

    param(
        [Parameter(Mandatory = $false)]
        [string]$command,

        [Parameter(Mandatory = $false)]
        [System.Object]$data,

        [Parameter(Mandatory = $true)]
        [string]$output_file,

        [switch]$append
    )

    begin {
        $command_string = "Command: $($command.ToString())`n`n"
    }
    process {
        if (-not $data) {
            "$($command_string) No data found when running this function." | Out-File -FilePath $output_file
        }
        else {
            if (-not $append) {
                $command_string | Out-File -FilePath $output_file -Encoding utf8
            }
            else {
                $command_string | Out-File -FilePath $output_file -Encoding utf8 -Append
            }
            $data | Out-File -FilePath $output_file -Encoding utf8 -Append
        }
    }
}

function Test-IfExists {
    param(
        [string]$folder_name,
        [string]$file_name,
        [ValidateSet("FOLDER","FILE")]
        [string]$type
    )

    if ($type -eq "FOLDER") {
        $folder_name_text = $(Split-Path -Path $folder_name -Leaf)
        if (Test-Path $folder_name) {
            $folder_created_msg = "---- `"$($folder_name_text)`" ---- sub-directory created successfully."
            Show-MessageAndWriteLogEntry -Msg $folder_created_msg -Level INFO
        }
        else {
            Show-MessageAndWriteLogEntry -Msg "The necessary sub-directory does not exist or could not be created -> `"$($folder_name_text)`"" -Level ERROR
            return
        }
    }
    if ($type -eq "FILE") {
        $file_name_text = $(Split-Path -Path $file_name -Leaf)
        if (Test-Path $file_name) {
            $file_created_msg = "The `"$($file_name_text)`" file was created successfully."
            Show-MessageAndWriteLogEntry -Msg $file_created_msg -Level INFO
        }
        else {
            Show-MessageAndWriteLogEntry -Msg "There was an error creating the `"$($file_name_text)`" file." -Level ERROR
            return
        }
    }
}
