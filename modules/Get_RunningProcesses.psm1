function Get-RunningProcesses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$results_folder
    )

    begin {
        $stopwatch           = [System.Diagnostics.Stopwatch]::StartNew()
        $computer_name       = $env:computername
        $run_process_capture = Read-Host -Prompt "`n[?] Do you want to run MAGNET ProcessCapture? (y/n)"
    }
    process {
        if ($run_process_capture -eq "y") {
            try {
                $begin_msg = "Starting Process Capture from computer: $($computer_name). Please wait..."
                Show-MessageAndWriteLogEntry -Msg $begin_msg -Level INFO

                # Make new directory to store the process .dmp files
                $process_capture_folder = Join-Path -Path $results_folder -ChildPath "Process_Capture"
                $null                   = New-Item -ItemType Directory -Path $process_capture_folder -Force

                Test-IfExists -FolderName $process_capture_folder -Type FOLDER

                # Run MAGNETProcessCapture.exe from the \bin directory and save the output to the results folder.
                # The program will create its own directory to save the results with the following naming convention:
                # 'MagnetProcessCapture-YYYYMMDD-HHMMSS'
                Start-Process -NoNewWindow -FilePath $binaries["MagnetProcessCapture"] -ArgumentList "/saveall '$process_capture_folder'" -Wait

                $execution_time = $stopwatch.Elapsed.TotalSeconds

                $success_msg = "Process Capture completed successfully from computer: $($computer_name)"
                Show-MessageAndWriteLogEntry -Msg $success_msg -Level SUCCESS

                Show-MessageAndWriteLogEntry -File $(Split-Path -Path $process_capture_folder -Leaf) -ExecutionTime "$($execution_time) seconds" -Level SUCCESS

                $stopwatch.Stop()
            }
            catch {
                $error_msg = "Execution failed during `"$($MyInvocation.MyCommand.Name)`". Error: $($_.Exception.Message)"
                Show-MessageAndWriteLogEntry -Msg $error_msg -Level ERROR
            }
        }
        elseif ($run_process_capture -eq "n") {
            $decline_msg = "`"$($MyInvocation.MyCommand.Name)`" DECLINED by the user."
            Show-MessageAndWriteLogEntry -Msg $decline_msg -Level WARNING
        }
        else {
            $no_valid_option_msg = "No valid option entered by the user, skipping the `"$($MyInvocation.MyCommand.Name)`" function."
            Show-MessageAndWriteLogEntry -Msg $no_valid_option_msg -Level WARNING
        }
    }
    end {
        if ($stopwatch.IsRunning) {
            $stopwatch.Stop()
        }
    }
}
