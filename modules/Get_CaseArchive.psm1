function Get-CaseArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$results_folder
    )

    begin {
        $stopwatch   = [System.Diagnostics.Stopwatch]::StartNew()
        $make_archive = Read-Host -Prompt "`n[?] Do you want to package the results into a .zip file? (y/n)"
    }
    process {
        if ($make_archive -eq "y") {
            try {
                $createArchiveMsg = "Creating Case Archive file -> `"$(Split-Path $results_folder -Leaf).zip`""
                Show-MessageAndWriteLogEntry -Msg $createArchiveMsg -Level INFO

                $results_folder_parent = Split-Path -Path $results_folder -Parent
                $results_folder_title  = (Get-Item -Path $results_folder).Name
                $archive_file_name     = "$results_folder_title.zip"

                Compress-Archive -Path $results_folder -DestinationPath "$results_folder_parent\$archive_file_name" -Force

                $execution_time = $stopwatch.Elapsed.TotalSeconds

                Show-MessageAndWriteLogEntry -File $archive_file_name -ExecutionTime "$($execution_time) seconds" -Level SUCCESS

                $stopwatch.Stop()
            }
            catch {
                $error_msg = "Execution failed during `"$($MyInvocation.MyCommand.Name)`". Error: $($_.Exception.Message)"
                Show-MessageAndWriteLogEntry -Msg $error_msg -Level ERROR
            }
        }
        elseif ($make_archive -eq "n") {
            $decline_msg = "`"$($MyInvocation.MyCommand.Name)`" DECLINED by the user."
            Show-MessageAndWriteLogEntry -Msg $decline_msg -Level WARNING
        }
        else {
            $no_valid_option_msg = "No valid option entered by the user, skipping `"$($MyInvocation.MyCommand.Name)`"."
            Show-MessageAndWriteLogEntry -Msg $no_valid_option_msg -Level WARNING
        }
    }
    end {
        if ($stopwatch.IsRunning) {
            $stopwatch.Stop()
        }
    }
}
