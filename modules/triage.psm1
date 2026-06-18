function Invoke-DfirTriageScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$results_folder
    )

    begin {
        $module_name = Split-Path -Path $PSCommandPath

        # Date Last Updated
        $dlu = "29-May-2026"

        # List of file types to use in some commands
        $executable_file_types = @(
            "*.BAT", "*.BIN", "*.CGI", "*.CMD", "*.COM", "*.DLL", "*.EXE",
            "*.JAR", "*.JOB", "*.JSE", "*.MSI", "*.PAF", "*.PS1", "*.SCR",
            "*.SCRIPT", "*.VB", "*.VBE", "*.VBS", "*.VBSCRIPT", "*.WS", "*.WSF"
        )

        $start_time = Get-Date

        $global:binaries = @{
            "MagnetRamCapture"     = ".\bin\MagnetRAMCapture.exe"
            "MagnetProcessCapture" = ".\bin\MagnetProcessCapture.exe"
            "PSInfo"               = ".\bin\PsInfo.exe"
            "SQLite3"              = ".\bin\sqlite3.exe"
            "EDD"                  = ".\bin\EDDv310.exe"
        }

        # Write the data to the log file and display start time message on the screen
        $header = "Script Log for VECTOR DFIR Script Usage"
        Write-LogMessage -Msg $header

        $start_msg = "'$($MyInvocation.MyCommand.Name)' execution started."
        Write-LogMessage -Msg $start_msg

        # Display the DFIR banner and instructions to the user
        $intro_banner = @"
+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
|                                     |
|   VECTOR Triage Script              |
|   Compiled by: Michael Sponheimer   |
|   Last Updated: $dlu         |
|                                     |
+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+

=============
INSTRUCTIONS
=============

[A] PURPOSE: Gather information from the target machine and
    save the data to outside storage device.
[B] The results will automatically be stored in a directory that
    is automatically created in the same directory from where this
    script is run.
[C] There are three (3) prompts that will require user input at the
    start.
[D] **IMPORTANT** DO NOT VIEW THE RESULTS OF THE SCAN ON THE TARGET
    MACHINE. MOVE THE COLLECTION DEVICE TO A FORENSIC MACHINE BEFORE
    OPENING ANY FILES!
[E] DO NOT close any pop-up windows that may appear.
[F] To get help for this script, run `"Get-Help .\PowerShell_DFIR_Script.ps1`"
    command from a PowerShell CLI prompt.

[G] To exit this script at anytime, press [Ctrl + C].
"@

        Show-Message -Msg $intro_banner -NoTime -TextColor Blue

        # Show-Message -Msg "`n--> Please read the instructions before executing the script! <--" -NoTime -TextColor Yellow

        # Stops the script until the user presses the ENTER key so the script does not begin before the user is ready
        Write-Host "`nPress [ENTER] after reading the instructions" -ForegroundColor Yellow

        #  Wait and loop until ONLY the Enter key is pressed
        do {
            # 'IncludeKeyDown' ensures we catch the press, 'NoEcho' prevents the key from printing to the screen
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } while ($key.VirtualKeyCode -ne 13) # 13 is the virtual key code for the Enter key

        # Move to the next line once [ENTER] is pressed
        Write-Host ""
    }
    process {

        Show-IsAdmin

        function Get-OperatorInfo {
            # Gather some basic operator information to add to the log file.
            param()

            $user     = Read-Host -Prompt "`n[-] Enter your name for the report"
            $user_msg = "Operator Name entered as: $($user)"
            Show-MessageAndWriteLogEntry -Msg $user_msg -Level INFO

            $agency     = Read-Host -Prompt "`n[-] Enter Agency Name"
            $agency_msg = "Agency Name entered as: $($agency)"
            Show-MessageAndWriteLogEntry -Msg $agency_msg -Level INFO

            $case_number     = Read-Host -Prompt "`n[-] Enter Case Number"
            $case_number_msg = "Case Number entered as: $($case_number)"
            Show-MessageAndWriteLogEntry -Msg $case_number_msg -Level INFO
        }

        Get-OperatorInfo


        Invoke-EncryptedDiskDetector -ResultsFolder $results_folder


        Get-RunningProcesses -ResultsFolder $results_folder


        Get-ComputerRam -ResultsFolder $results_folder


        function Initialize-TriageScan {
            [CmdletBinding()]
            param(
                [string]$results_folder
            )

            function Invoke-TriageScan {
                param(
                    [string]$folder_name,
                    [scriptblock]$action
                )
                try {
                    $sub_folder_path_name = Join-Path -Path $results_folder -ChildPath $folder_name
                    $null                 = New-Item -ItemType Directory -Path $sub_folder_path_name -Force
                    Test-IfExists -FolderName $sub_folder_path_name -Type FOLDER
                    & $action
                }
                catch {
                    $error_msg = "Execution failed during `"$($MyInvocation.MyCommand.Name)`". Error: $($_.Exception.Message)"
                    Show-MessageAndWriteLogEntry -Msg $error_msg -Level ERROR
                }
            }


            $dfir_scan_workflow = [ordered]@{
                "001_Device"     = { Get-TriageDeviceData -DeviceFolder $sub_folder_path_name }
                "002_Users"      = { Get-TriageUserData -UserFolder $sub_folder_path_name }
                "003_Network"    = { Get-TriageNetworkData -NetworkFolder $sub_folder_path_name }
                "004_Process"    = { Get-TriageProcessData -ProcessFolder $sub_folder_path_name }
                "005_System"     = { Get-TriageSystemData -SystemFolder $sub_folder_path_name }
                "006_Prefetch"   = { Get-TriagePrefetchData -PrefetchFolder $sub_folder_path_name }
                "007_Event_Logs" = { Get-TriageEventLogData -EventLogFolder $sub_folder_path_name }
                "008_Firewall"   = { Get-TriageFirewallData -FirewallFolder $sub_folder_path_name }
                "009_Encryption" = { Get-TriageEncryptionData -EncryptionFolder $sub_folder_path_name }
                "010_Internet"   = { Invoke-GetInternetInfo -InternetFolder $sub_folder_path_name }
            }

            foreach ($entry in $dfir_scan_workflow.GetEnumerator()) {
                Invoke-TriageScan -FolderName $entry.key -Action $entry.value
            }
        }


        Initialize-TriageScan -ResultsFolder $results_folder


        Get-FileHashes -ResultsFolder $results_folder


        Get-CaseArchive -ResultsFolder $results_folder


        $end_time = Get-Date
        $duration = $end_time - $start_time

        $duration_format = "{0} days, {1} hour(s), {2} minutes, {3} seconds" -f `
        $duration.Days,
        $duration.Hours,
        $duration.Minutes,
        $duration.Seconds

        Write-Host "`nScript execution completed in $duration_format."
        Write-Host "`nThe results are available in the '$results_folder' directory"
    }
    end {
        # Force the .NET Garbage Collector to immediately purge the freed memory slots
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
}
