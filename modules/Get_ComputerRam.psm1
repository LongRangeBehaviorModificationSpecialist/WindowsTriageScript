function Get-ComputerRam {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$resultsFolder
    )

    begin {
        $stopwatch     = [System.Diagnostics.Stopwatch]::StartNew()
        $computerName  = $env:computername
        $runRamCapture = Read-Host -Prompt "`n[?] Do you want to run MAGNET Ram Capture on $computerName? (y/n)"
    }
    process {
        if ($runRamCapture -eq "y") {
            try {
                $beginMessage = "Starting RAM capture from computer: $($computerName). Please wait..."
                Show-MessageAndWriteLogEntry -Message $beginMessage -Level INFO

                $ramCaptureFolder = Join-Path -Path $resultsFolder -ChildPath "Ram_Capture"
                $null             = New-Item -ItemType Directory -Path $ramCaptureFolder -Force

                Test-IfExists -FolderName $ramCaptureFolder -Type FOLDER

                # Start the RAM acquisition from the current machine
                Start-Process -NoNewWindow -FilePath $binaries["MagnetRamCapture"] -ArgumentList "/accepteula /go /silent" -Wait

                # Once the RAM has been acquired, move the file to the 'RAM' folder
                Move-Item -Path .\bin\*.raw -Destination $ramCaptureFolder -Force

                $ramCaptureFileName   = (Get-ChildItem -Path $ramCaptureFolder -Filter "*.raw").Name
                $executionTime = $stopwatch.Elapsed.TotalSeconds

                $successMsg = "RAM capture completed successfully from computer: $($computerName)"
                Show-MessageAndWriteLogEntry -Message $successMsg -Level SUCCESS

                Show-MessageAndWriteLogEntry -File $ramCaptureFileName -ExecutionTime "$($executionTime) seconds" -Level SUCCESS

                $stopwatch.Stop()
            }
            catch {
                $errorMessage = "Execution failed during '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
                Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
            }
        }
        elseif ($runRamCapture -eq "n") {
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
