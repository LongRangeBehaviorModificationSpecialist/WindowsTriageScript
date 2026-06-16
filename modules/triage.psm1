function Invoke-DfirTriageScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$resultsFolder
    )

    begin {
        $moduleName = Split-Path -Path $PSCommandPath

        # Date Last Updated
        $dlu = "29-May-2026"

        # List of file types to use in some commands
        $executableFileTypes = @(
            "*.BAT", "*.BIN", "*.CGI", "*.CMD", "*.COM", "*.DLL", "*.EXE",
            "*.JAR", "*.JOB", "*.JSE", "*.MSI", "*.PAF", "*.PS1", "*.SCR",
            "*.SCRIPT", "*.VB", "*.VBE", "*.VBS", "*.VBSCRIPT", "*.WS", "*.WSF"
        )

        $startTime = Get-Date

        $global:binaries = @{
            "MagnetRamCapture"     = ".\bin\MagnetRAMCapture.exe"
            "MagnetProcessCapture" = ".\bin\MagnetProcessCapture.exe"
            "PSInfo"               = ".\bin\PsInfo.exe"
            "SQLite3"              = ".\bin\sqlite3.exe"
            "EDD"                  = ".\bin\EDDv310.exe"
        }

        # Write the data to the log file and display start time message on the screen
        $header = "Script Log for VECTOR DFIR Script Usage"
        Write-LogMessage -Message $header

        $startMessage = "'$($MyInvocation.MyCommand.Name)' execution started."
        Write-LogMessage -Message $startMessage

        # Display the DFIR banner and instructions to the user
        $introBanner = @"
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

        Show-Message -Message $introBanner -NoTime -TextColor Blue

        # Show-Message -Message "`n--> Please read the instructions before executing the script! <--" -NoTime -TextColor Yellow

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

            $user    = Read-Host -Prompt "`n[-] Enter your name for the report"
            $userMsg = "Operator Name entered as: $($user)"
            Show-MessageAndWriteLogEntry -Message $userMsg -Level INFO

            $agency    = Read-Host -Prompt "`n[-] Enter Agency Name"
            $agencyMsg = "Agency Name entered as: $($agency)"
            Show-MessageAndWriteLogEntry -Message $agencyMsg -Level INFO

            $caseNumber    = Read-Host -Prompt "`n[-] Enter Case Number"
            $caseNumberMsg = "Case Number entered as: $($caseNumber)"
            Show-MessageAndWriteLogEntry -Message $caseNumberMsg -Level INFO
        }

        Get-OperatorInfo


        Invoke-EncryptedDiskDetector -ResultsFolder $resultsFolder


        Get-RunningProcesses -ResultsFolder $resultsFolder


        Get-ComputerRam -ResultsFolder $resultsFolder


        function Initialize-TriageScan {
            [CmdletBinding()]
            param(
                [string]$resultsFolder
            )

            function Invoke-TriageScan {
                param(
                    [string]$folderName,
                    [scriptblock]$action
                )
                try {
                    $subFolderPathName = Join-Path -Path $resultsFolder -ChildPath $folderName
                    $null              = New-Item -ItemType Directory -Path $subFolderPathName -Force
                    Test-IfExists -FolderName $subFolderPathName -Type FOLDER
                    & $action
                }
                catch {
                    $errorMessage = "Execution failed during '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
                    Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
                }
            }


            $dfirScanWorkflow = [ordered]@{
                "001_Device"     = { Get-TriageDeviceData -DeviceFolder $subFolderPathName }
                "002_Users"      = { Get-TriageUserData -UserFolder $subFolderPathName }
                "003_Network"    = { Get-TriageNetworkData -NetworkFolder $subFolderPathName }
                "004_Process"    = { Get-TriageProcessData -ProcessFolder $subFolderPathName }
                "005_System"     = { Get-TriageSystemData -SystemFolder $subFolderPathName }
                "006_Prefetch"   = { Get-TriagePrefetchData -PrefetchFolder $subFolderPathName }
                "007_Event_Logs" = { Get-TriageEventLogData -EventLogFolder $subFolderPathName }
                "008_Firewall"   = { Get-TriageFirewallData -FirewallFolder $subFolderPathName }
                "009_Encryption" = { Get-TriageEncryptionData -EncryptionFolder $subFolderPathName }
                "010_Internet"   = { Invoke-GetInternetInfo -InternetFolder $subFolderPathName }
            }

            foreach ($entry in $dfirScanWorkflow.GetEnumerator()) {
                Invoke-TriageScan -FolderName $entry.key -Action $entry.value
            }
        }


        Initialize-TriageScan -ResultsFolder $resultsFolder


        Get-FileHashes -ResultsFolder $resultsFolder


        Get-CaseArchive -ResultsFolder $resultsFolder


        $endTime = Get-Date
        $duration = $endTime - $startTime

        $durationFormat = "{0} days, {1} hour(s), {2} minutes, {3} seconds" -f `
        $duration.Days,
        $duration.Hours,
        $duration.Minutes,
        $duration.Seconds

        Write-Host "`nScript execution completed in $durationFormat."
        Write-Host "`nThe results are available in the '$resultsFolder' directory"
    }
    end {
        # Force the .NET Garbage Collector to immediately purge the freed memory slots
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
}
