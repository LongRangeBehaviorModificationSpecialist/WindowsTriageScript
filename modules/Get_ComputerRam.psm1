function Get-ComputerRam {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsFolder
    )

    begin {
        $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $ComputerName = $env:computername
        $RunRamCapture = Read-Host -Prompt "`n[?] Do you want to run MAGNET Ram Capture on $ComputerName? (y/n)"
    }
    process {
        if ($RunRamCapture -eq "y") {
            try {
                $BeginMsg = "Starting RAM capture from computer: $( $ComputerName ). Please wait..."
                Show-MessageAndWriteLogEntry -Msg $BeginMsg -Level INFO

                $RamCaptureFolder = Join-Path -Path $ResultsFolder -ChildPath "Ram_Capture"
                $null = New-Item -ItemType Directory -Path $RamCaptureFolder -Force

                Test-IfExists -FolderName $RamCaptureFolder -Type FOLDER

                # Start the RAM acquisition from the current machine
                Start-Process -NoNewWindow -FilePath $Binaries["MagnetRamCapture"] -ArgumentList "/accepteula /go /silent" -Wait

                # Once the RAM has been acquired, move the file to the 'RAM' folder
                Move-Item -Path .\bin\*.raw -Destination $RamCaptureFolder -Force

                $RamCaptureFileName = (Get-ChildItem -Path $RamCaptureFolder -Filter "*.raw").Name
                $ExecutionTime = $Stopwatch.Elapsed.TotalSeconds

                $SuccessMsg = "RAM capture completed successfully from computer: $( $ComputerName )"
                Show-MessageAndWriteLogEntry -Msg $SuccessMsg -Level SUCCESS

                Show-MessageAndWriteLogEntry -File $RamCaptureFileName -ExecutionTime "$( $ExecutionTime ) seconds" -Level SUCCESS

                $Stopwatch.Stop()
            }
            catch {
                $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error: $( $_.Exception.Message )"
                Show-MessageAndWriteLogEntry -Msg $ErrorMsg -Level ERROR
            }
        }
        elseif ($RunRamCapture -eq "n") {
            $DeclineMsg = "'$( $MyInvocation.MyCommand.Name )' DECLINED by the user."
            Show-MessageAndWriteLogEntry -Msg $DeclineMsg -Level WARNING
        }
        else {
            $NoValidOptionMsg = "No valid option entered by the user, skipping the '$( $MyInvocation.MyCommand.Name )' function."
            Show-MessageAndWriteLogEntry -Msg $NoValidOptionMsg -Level WARNING
        }
    }
    end {
        if ($Stopwatch.IsRunning) {
            $Stopwatch.Stop()
        }
    }
}
