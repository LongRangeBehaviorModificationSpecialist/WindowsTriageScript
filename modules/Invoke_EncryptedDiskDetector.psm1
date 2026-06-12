function Invoke-EncryptedDiskDetector {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$resultsFolder
    )

    begin {
        $stopwatch    = [System.Diagnostics.Stopwatch]::StartNew()
        $computerName = $env:computername
        $runEdd       = Read-Host -Prompt "`n[?] Do you want to run Encrypted Disk Detector on $computerName? (y/n)"
    }
    process {
        if ($runEdd -eq "y") {
            try {
                $beginMessage = "Starting Encrypted Disk Detector on: $computerName"
                Show-MessageAndWriteLogEntry -Message $beginMessage -Level INFO

                $eddResultsFolder = Join-Path -Path $resultsFolder -ChildPath "Encrypted_Disk_Detector"
                $null = New-Item -ItemType Directory -Path $eddResultsFolder -Force

                Test-IfExists -FolderName $eddResultsFolder -Type FOLDER

                # Name the file to which the scan results will be saved
                $eddResultsFilePath = Join-Path -Path $eddResultsFolder -ChildPath "encrypted_disk_detector_results.txt"
                $null = New-Item -ItemType File -Path $eddResultsFilePath -Force
                $eddResultsFileName = [System.IO.Path]::GetFileName($eddResultsFilePath)

                Test-IfExists -FileName $eddResultsFilePath -Type FILE

                # Start the encrypted disk detector executable
                Start-Process -NoNewWindow -FilePath $binaries["EDD"] -ArgumentList "/batch" -Wait -RedirectStandardOutput $eddResultsFilePath

                $currentExecutionTime = $stopwatch.Elapsed.TotalSeconds

                $successMsg = "Encrypted Disk Detector was run successfully on computer: $computerName"
                Show-MessageAndWriteLogEntry -Message $successMsg -File $eddResultsFileName -ExecutionTime "$currentExecutionTime seconds" -Level SUCCESS

                $stopwatch.Stop()

                # Read the contents of the EDD text file and show the results on the screen
                Get-Content -Path $eddResultsFilePath -Force
            }
            catch {
                $errorMessage = "Execution failed during '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
                Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
            }
        }
        elseif ($runEdd -eq "n") {
            $declineMsg = "'$($MyInvocation.MyCommand.Name)' DECLINED by the user."
            Show-MessageAndWriteLogEntry -Message $declineMsg -Level WARNING
        }
        else {
            $noValidOptionMsg = "No valid option entered by the user, skipping the '$($MyInvocation.MyCommand.Name)' function."
            Show-MessageAndWriteLogEntry -Message $noValidOptionMsg -Level WARNING
        }
    }
    end {
        if ($stopwatch.IsRunning) {
            $stopwatch.Stop()
        }
    }
}
