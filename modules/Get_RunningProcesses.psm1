function Get-RunningProcesses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsFolder
    )

    begin {
        $Stopwatch         = [System.Diagnostics.Stopwatch]::StartNew()
        $ComputerName      = $env:computername
        $RunProcessCapture = Read-Host -Prompt "`n[?] Do you want to run MAGNET ProcessCapture? (y/n)"
    }
    process {
        if ($RunProcessCapture -eq "y") {
            try {
                $BeginMsg = "Starting Process Capture from computer: $( $ComputerName ). Please wait..."
                Show-MessageAndWriteLogEntry -Msg $BeginMsg -Level INFO

                # Make new directory to store the process .dmp files
                $ProcessCaptureFolder = Join-Path -Path $ResultsFolder -ChildPath "Process_Capture"
                $null                 = New-Item -ItemType Directory -Path $ProcessCaptureFolder -Force

                Test-IfExists -FolderName $ProcessCaptureFolder -Type FOLDER

                <#
                Run MAGNETProcessCapture.exe from the \bin directory and save the output to the results folder.
                The program will create its own directory to save the results with the following naming convention:
                'MagnetProcessCapture-YYYYMMDD-HHMMSS'
                #>
                Start-Process -NoNewWindow -FilePath $Binaries["MagnetProcessCapture"] -ArgumentList "/saveall '$ProcessCaptureFolder'" -Wait

                $ExecutionTime = $Stopwatch.Elapsed.TotalSeconds

                $SuccessMsg = "Process Capture completed successfully from computer: $( $ComputerName )"
                Show-MessageAndWriteLogEntry -Msg $SuccessMsg -Level SUCCESS

                Show-MessageAndWriteLogEntry -File $(Split-Path -Path $ProcessCaptureFolder -Leaf) -ExecutionTime "$( $ExecutionTime ) seconds" -Level SUCCESS

                $Stopwatch.Stop()
            }
            catch {
                $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error: $( $_.Exception.Message )"
                Show-MessageAndWriteLogEntry -Msg $ErrorMsg -Level ERROR
            }
        }
        elseif ($RunProcessCapture -eq "n") {
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
