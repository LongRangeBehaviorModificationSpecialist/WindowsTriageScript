function Get-CaseArchive {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [string]$ResultsFolder
    )

    begin {
        $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $ComputerName = $env:computername
        $MakeArchive = Read-LogHost -Prompt "Do you want to package the results from $( $ComputerName ) into a .zip file? (y/n): "
    }
    process {
        if ($MakeArchive -eq "y") {
            try {
                $CreateArchiveMsg = "Creating Case Archive file -> '$(Split-Path $ResultsFolder -Leaf).zip'"
                Show-Message -Message $CreateArchiveMsg -Level INFO -AddToLog

                $ResultsFolderParent = Split-Path -Path $ResultsFolder -Parent
                $ResultsFolderTitle = (Get-Item -Path $ResultsFolder).Name
                $ArchiveFileName = "$ResultsFolderTitle.zip"

                Compress-Archive -Path $ResultsFolder -DestinationPath "$ResultsFolderParent\$ArchiveFileName" -Force

                $ExecutionTime = $Stopwatch.Elapsed.TotalSeconds

                Show-Message -File $ArchiveFileName -ExecutionTime "$( $ExecutionTime ) seconds" -Level SUCCESS -AddToLog

                $Stopwatch.Stop()
            }
            catch {
                $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name ) on $( $ComputerName )'. Error -> $( $_.Exception.Message )"
                Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
            }
        }
        elseif ($MakeArchive -eq "n") {
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
