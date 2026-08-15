function Invoke-DfirTriageScan {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [string]$ResultsFolder
    )

    begin {
        $ModuleName = Split-Path -Path $PSCommandPath

        # Date Last Updated
        $Dlu = "15-Aug-2026"

        # List of file types to use in some commands
        $ExecutableFileTypes = @(
            "*.BAT", "*.BIN", "*.CGI", "*.CMD", "*.COM", "*.DLL", "*.EXE",
            "*.JAR", "*.JOB", "*.JSE", "*.MSI", "*.PAF", "*.PS1", "*.SCR",
            "*.SCRIPT", "*.VB", "*.VBE", "*.VBS", "*.VBSCRIPT", "*.WS", "*.WSF"
        )

        $StartTime = Get-Date

        $global:Binaries = @{
            "MagnetRamCapture"     = ".\bin\MagnetRAMCapture.exe"
            "MagnetProcessCapture" = ".\bin\MagnetProcessCapture.exe"
            "PSInfo"               = ".\bin\PsInfo.exe"
            "SQLite3"              = ".\bin\sqlite3.exe"
            "EDD"                  = ".\bin\EDDv310.exe"
        }

        # Write the data to the log file and display start time message on the screen
        $Header = "Script Log for VECTOR DFIR Script Usage"
        Write-LogMessage -Message $Header

        $StartMsg = "'$( $MyInvocation.MyCommand.Name )' execution started."
        Write-LogMessage -Message $StartMsg

        # Display the DFIR banner and instructions to the user
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
[4] There are three (3) prompts that will require user input at the
    start.
[5] **IMPORTANT** DO NOT VIEW THE RESULTS OF THE SCAN ON THE TARGET
    MACHINE. MOVE THE COLLECTION DEVICE TO A FORENSIC MACHINE BEFORE
    OPENING ANY FILES!
[6] DO NOT close any pop-up windows that may appear.
[7] To get help for this script, run 'Get-Help .\run-triage.ps1'
    command from a PowerShell CLI prompt.

[8] To exit this script at anytime, press [Ctrl + C].
"@

        Show-Message -Message $IntroBanner -NoTime -MessageColor Green

        # Stops the script until the user presses the ENTER key so the script does not begin before the user is ready
        Write-Host "`nPress [ENTER] after reading the instructions" -ForegroundColor Yellow

        #  Wait and loop until ONLY the Enter key is pressed
        do {
            # 'IncludeKeyDown' ensures we catch the press, 'NoEcho' prevents the key from printing to the screen
            $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } while ($Key.VirtualKeyCode -ne 13) # 13 is the virtual key code for the Enter key

        # Move to the next line once [ENTER] is pressed
        Write-Host ""
    }
    process {

        Show-IsAdmin

        function Get-OperatorInfo {
            # Gather some basic operator information to add to the log file.
            param()

            $User     = Read-LogHost -Prompt "Enter your name for the report: "
            $UserMsg  = "Operator Name recorded as: $User"
            Show-Message -Message $UserMsg -Level INFO -AddToLog -MessageColor Green

            $Agency    = Read-LogHost -Prompt "Enter Agency Name: "
            $AgencyMsg = "Agency Name recorded as: $Agency"
            Show-Message -Message $AgencyMsg -Level INFO -AddToLog -MessageColor Green

            $CaseNumber     = Read-LogHost -Prompt "Enter Case Number: "
            $CaseNumberMsg  = "Case Number recorded  as: $CaseNumber"
            Show-Message -Message $CaseNumberMsg -Level INFO -AddToLog -MessageColor Green
        }

        Get-OperatorInfo


        Invoke-EncryptedDiskDetector -ResultsFolder $ResultsFolder


        Get-RunningProcesses -ResultsFolder $ResultsFolder


        Get-ComputerRam -ResultsFolder $ResultsFolder


        function Initialize-TriageScan {
            [CmdletBinding()]
            param(
                [string]$ResultsFolder
            )

            function Invoke-TriageScan {
                param(
                    [string]$FolderName,
                    [scriptblock]$Action
                )
                try {
                    $SubFolderPathName = Join-Path -Path $ResultsFolder -ChildPath $FolderName
                    $null              = New-Item -ItemType Directory -Path $SubFolderPathName -Force

                    Test-IfExists -FolderName $SubFolderPathName -Type FOLDER
                    & $Action
                }
                catch {
                    $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )' on $( $ComputerName ). Error -> $( $_.Exception.Message )"
                    Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
                }
            }


            $DfirScanWorkflow = [ordered]@{
                "001_Device"     = { Get-TriageDeviceData -DeviceFolder $SubFolderPathName }
                "002_Users"      = { Get-TriageUserData -UserFolder $SubFolderPathName }
                "003_Network"    = { Get-TriageNetworkData -NetworkFolder $SubFolderPathName }
                "004_Process"    = { Get-TriageProcessData -ProcessFolder $SubFolderPathName }
                "005_System"     = { Get-TriageSystemData -SystemFolder $SubFolderPathName }
                "006_Prefetch"   = { Get-TriagePrefetchData -PrefetchFolder $SubFolderPathName }
                "007_Event_Logs" = { Get-TriageEventLogData -EventLogFolder $SubFolderPathName }
                "008_Firewall"   = { Get-TriageFirewallData -FirewallFolder $SubFolderPathName }
                "009_Encryption" = { Get-TriageEncryptionData -EncryptionFolder $SubFolderPathName }
                "010_Internet"   = { Get-TriageInternetData -InternetFolder $SubFolderPathName }
            }

            foreach ($Entry in $DfirScanWorkflow.GetEnumerator()) {
                Invoke-TriageScan -FolderName $Entry.key -Action $Entry.value
            }
        }


        Initialize-TriageScan -ResultsFolder $ResultsFolder


        Get-FileHashes -ResultsFolder $ResultsFolder -LogFile $LogFole


        Get-CaseArchive -ResultsFolder $ResultsFolder


        $EndTime = Get-Date
        $Duration = $EndTime - $StartTime

        $DurationFormat = "{0} days, {1} hour(s), {2} minutes, {3} seconds" -f `
        $Duration.Days,
        $Duration.Hours,
        $Duration.Minutes,
        $Duration.Seconds

        Write-Host "`nScript execution completed in $DurationFormat."
        Write-Host "`nThe results are available in the '$ResultsFolder' directory"
    }
    end {
        # Force the .NET Garbage Collector to immediately purge the freed memory slots
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
}
