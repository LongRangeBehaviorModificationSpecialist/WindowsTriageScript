function Get-ComputerRam {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$results_folder
    )

    begin {
        $stopwatch       = [System.Diagnostics.Stopwatch]::StartNew()
        $computer_name   = $env:computername
        $run_ram_capture = Read-Host -Prompt "`n[?] Do you want to run MAGNET Ram Capture on $computer_name? (y/n)"
    }
    process {
        if ($run_ram_capture -eq "y") {
            try {
                $begin_msg = "Starting RAM capture from computer: $($computer_name). Please wait..."
                Show-MessageAndWriteLogEntry -Msg $begin_msg -Level INFO

                $ram_capture_folder = Join-Path -Path $results_folder -ChildPath "Ram_Capture"
                $null               = New-Item -ItemType Directory -Path $ram_capture_folder -Force

                Test-IfExists -FolderName $ram_capture_folder -Type FOLDER

                # Start the RAM acquisition from the current machine
                Start-Process -NoNewWindow -FilePath $binaries["MagnetRamCapture"] -ArgumentList "/accepteula /go /silent" -Wait

                # Once the RAM has been acquired, move the file to the 'RAM' folder
                Move-Item -Path .\bin\*.raw -Destination $ram_capture_folder -Force

                $ram_capture_file_name   = (Get-ChildItem -Path $ram_capture_folder -Filter "*.raw").Name
                $execution_time = $stopwatch.Elapsed.TotalSeconds

                $success_msg = "RAM capture completed successfully from computer: $($computer_name)"
                Show-MessageAndWriteLogEntry -Msg $success_msg -Level SUCCESS

                Show-MessageAndWriteLogEntry -File $ram_capture_file_name -ExecutionTime "$($execution_time) seconds" -Level SUCCESS

                $stopwatch.Stop()
            }
            catch {
                $error_msg = "Execution failed during `"$($MyInvocation.MyCommand.Name)`". Error: $($_.Exception.Message)"
                Show-MessageAndWriteLogEntry -Msg $error_msg -Level ERROR
            }
        }
        elseif ($run_ram_capture -eq "n") {
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
