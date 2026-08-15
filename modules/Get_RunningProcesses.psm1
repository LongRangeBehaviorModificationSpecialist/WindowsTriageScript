function Get-RunningProcesses {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [string]$ResultsFolder
    )

    begin {
        $Stopwatch         = [System.Diagnostics.Stopwatch]::StartNew()
        $ComputerName      = $env:computername
        $RunProcessCapture = Read-LogHost -Prompt "Do you want to run MAGNET Process Capture on $( $ComputerName )? (y/n): "
    }
    process {
        if ($RunProcessCapture -eq "y") {
            try {
                $BeginMsg = "Starting Process Capture from computer: $( $ComputerName ). Please wait..."
                Show-Message -Message $BeginMsg -Level INFO -AddToLog

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
                Show-Message -Message $SuccessMsg -Level SUCCESS -AddToLog

                Show-Message -File $(Split-Path -Path $ProcessCaptureFolder -Leaf) -ExecutionTime "$( $ExecutionTime ) seconds" -Level SUCCESS -AddToLog

                $Stopwatch.Stop()
            }
            catch {
                $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )' on $( $ComputerName ). Error -> $( $_.Exception.Message )"
                Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
            }
        }
        elseif ($RunProcessCapture -eq "n") {
            $DeclineMsg = "Executing '$( $MyInvocation.MyCommand.Name )' on $( $ComputerName ) was DECLINED by the user."
            Show-Message -Message $DeclineMsg -Level WARNING -AddToLog
        }
        else {
            $NoValidOptionMsg = "No valid option entered by the user, skipping the '$( $MyInvocation.MyCommand.Name )' function for $( $ComputerName )."
            Show-Message -Message $NoValidOptionMsg -Level WARNING -AddToLog
        }
    }
    end {
        if ($Stopwatch.IsRunning) {
            $Stopwatch.Stop()
        }
    }
}
