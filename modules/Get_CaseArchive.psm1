function Get-CaseArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$resultsFolder
    )

    begin {
        $stopwatch   = [System.Diagnostics.Stopwatch]::StartNew()
        $makeArchive = Read-Host -Prompt "`n[?] Do you want to package the results into a .zip file? (y/n)"
    }
    process {
        if ($makeArchive -eq "y") {
            try {
                $createArchiveMsg = "Creating Case Archive file -> '$(Split-Path $resultsFolder -Leaf).zip'"
                Show-MessageAndWriteLogEntry -Message $createArchiveMsg -Level INFO

                $resultsFolderParent = Split-Path -Path $resultsFolder -Parent
                $resultsFolderTitle  = (Get-Item -Path $resultsFolder).Name
                $archiveFileName     = "$resultsFolderTitle.zip"

                Compress-Archive -Path $resultsFolder -DestinationPath "$resultsFolderParent\$archiveFileName" -Force

                $executionTime = $stopwatch.Elapsed.TotalSeconds

                Show-MessageAndWriteLogEntry -File $archiveFileName -ExecutionTime "$($executionTime) seconds" -Level SUCCESS

                $stopwatch.Stop()
            }
            catch {
                $errorMessage = "Execution failed during '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
                Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
            }
        }
        elseif ($makeArchive -eq "n") {
            $declineMsg = "'$($MyInvocation.MyCommand.Name)' DECLINED by the user."
            Show-MessageAndWriteLogEntry -Message $declineMsg -Level WARNING
        }
        else {
            $noValidOptionMsg = "No valid option entered by the user, skipping '$($MyInvocation.MyCommand.Name)'."
            Show-MessageAndWriteLogEntry -Message $noValidOptionMsg -Level WARNING
        }
    }
    end {
        if ($stopwatch.IsRunning) {
            $stopwatch.Stop()
        }
    }
}
