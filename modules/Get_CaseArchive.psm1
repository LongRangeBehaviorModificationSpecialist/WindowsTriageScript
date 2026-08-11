function Get-CaseArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsFolder
    )

    begin {
        $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $MakeArchive = Read-Host -Prompt "`n[?] Do you want to package the results into a .zip file? (y/n)"
    }
    process {
        if ($MakeArchive -eq "y") {
            try {
                $CreateArchiveMsg = "Creating Case Archive file -> '$(Split-Path $ResultsFolder -Leaf).zip'"
                Show-MessageAndWriteLogEntry -Msg $CreateArchiveMsg -Level INFO

                $ResultsFolderParent = Split-Path -Path $ResultsFolder -Parent
                $ResultsFolderTitle = (Get-Item -Path $ResultsFolder).Name
                $ArchiveFileName = "$ResultsFolderTitle.zip"

                Compress-Archive -Path $ResultsFolder -DestinationPath "$ResultsFolderParent\$ArchiveFileName" -Force

                $ExecutionTime = $Stopwatch.Elapsed.TotalSeconds

                Show-MessageAndWriteLogEntry -File $ArchiveFileName -ExecutionTime "$( $ExecutionTime ) seconds" -Level SUCCESS

                $Stopwatch.Stop()
            }
            catch {
                $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error: $( $_.Exception.Message )"
                Show-MessageAndWriteLogEntry -Msg $ErrorMsg -Level ERROR
            }
        }
        elseif ($MakeArchive -eq "n") {
            $DeclineMsg = "'$( $MyInvocation.MyCommand.Name )' DECLINED by the user."
            Show-MessageAndWriteLogEntry -Msg $DeclineMsg -Level WARNING
        }
        else {
            $NoValidOptionMsg = "No valid option entered by the user, skipping '$( $MyInvocation.MyCommand.Name )'."
            Show-MessageAndWriteLogEntry -Msg $NoValidOptionMsg -Level WARNING
        }
    }
    end {
        if ($Stopwatch.IsRunning) {
            $Stopwatch.Stop()
        }
    }
}
