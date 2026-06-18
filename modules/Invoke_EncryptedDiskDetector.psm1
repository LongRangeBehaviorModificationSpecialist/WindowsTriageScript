function Invoke-EncryptedDiskDetector {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$results_folder
    )

    begin {
        $stopwatch    = [System.Diagnostics.Stopwatch]::StartNew()
        $computer_name = $env:computername
        $run_edd       = Read-Host -Prompt "`n[?] Do you want to run Encrypted Disk Detector on $computer_name? (y/n)"
    }
    process {
        if ($run_edd -eq "y") {
            try {
                $begin_msg = "Starting Encrypted Disk Detector on: $($computer_name)"
                Show-MessageAndWriteLogEntry -Msg $begin_msg -Level INFO

                $edd_results_folder = Join-Path -Path $results_folder -ChildPath "Encrypted_Disk_Detector"
                $null             = New-Item -ItemType Directory -Path $edd_results_folder -Force

                Test-IfExists -FolderName $edd_results_folder -Type FOLDER

                # Name the file to which the scan results will be saved
                $edd_results_file_path = Join-Path -Path $edd_results_folder -ChildPath "encrypted_disk_detector_results.txt"
                $null                  = New-Item -ItemType File -Path $edd_results_file_path -Force
                $edd_results_file_name = [System.IO.Path]::GetFileName($edd_results_file_path)

                Test-IfExists -FileName $edd_results_file_path -Type FILE

                # Start the encrypted disk detector executable
                Start-Process -NoNewWindow -FilePath $binaries["EDD"] -ArgumentList "/batch" -Wait -RedirectStandardOutput $edd_results_file_path

                $execution_time = $stopwatch.Elapsed.TotalSeconds

                $success_msg = "Encrypted Disk Detector was run successfully on computer: $($computer_name)"
                Show-MessageAndWriteLogEntry -Msg $success_msg -File $edd_results_file_name -ExecutionTime "$($execution_time) seconds" -Level SUCCESS

                $stopwatch.Stop()

                # Read the contents of the EDD text file and show the results on the screen
                Get-Content -Path $edd_results_file_path -Force
            }
            catch {
                $error_msg = "Execution failed during `"$($MyInvocation.MyCommand.Name)`". Error: $($_.Exception.Message)"
                Show-MessageAndWriteLogEntry -Msg $error_msg -Level ERROR
            }
        }
        elseif ($run_edd -eq "n") {
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
