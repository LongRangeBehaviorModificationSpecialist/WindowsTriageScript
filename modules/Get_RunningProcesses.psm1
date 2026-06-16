function Get-RunningProcesses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$resultsFolder
    )

    begin {
        $stopwatch         = [System.Diagnostics.Stopwatch]::StartNew()
        $computerName      = $env:computername
        $runProcessCapture = Read-Host -Prompt "`n[?] Do you want to run MAGNET ProcessCapture? (y/n)"
    }
    process {
        if ($runProcessCapture -eq "y") {
            try {
                $beginMessage = "Starting Process Capture from computer: $($computerName). Please wait..."
                Show-MessageAndWriteLogEntry -Message $beginMessage -Level INFO

                # Make new directory to store the process .dmp files
                $processCaptureFolder = Join-Path -Path $resultsFolder -ChildPath "Process_Capture"
                $null                 = New-Item -ItemType Directory -Path $processCaptureFolder -Force

                Test-IfExists -FolderName $processCaptureFolder -Type FOLDER

                # Run MAGNETProcessCapture.exe from the \bin directory and save the output to the results folder.
                # The program will create its own directory to save the results with the following naming convention:
                # 'MagnetProcessCapture-YYYYMMDD-HHMMSS'
                Start-Process -NoNewWindow -FilePath $binaries["MagnetProcessCapture"] -ArgumentList "/saveall '$processCaptureFolder'" -Wait

                $executionTime = $stopwatch.Elapsed.TotalSeconds

                $successMsg = "Process Capture completed successfully from computer: $($computerName)"
                Show-MessageAndWriteLogEntry -Message $successMsg -Level SUCCESS

                Show-MessageAndWriteLogEntry -File $(Split-Path -Path $processCaptureFolder -Leaf) -ExecutionTime "$($executionTime) seconds" -Level SUCCESS

                $stopwatch.Stop()
            }
            catch {
                $errorMessage = "Execution failed during '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
                Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
            }
        }
        elseif ($runProcessCapture -eq "n") {
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
