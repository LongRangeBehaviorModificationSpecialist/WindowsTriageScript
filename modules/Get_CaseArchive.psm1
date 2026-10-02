function Get-CaseArchive {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [string]$ResultsFolder
    )

    begin {
        $Stopwatch    = [System.Diagnostics.Stopwatch]::StartNew()
        $ComputerName = $env:computername
    }
    process {
        try {
            $CreateArchiveMsg = "Creating Case Archive file => '$(Split-Path $ResultsFolder -Leaf).zip'"
            Show-Message -Message $CreateArchiveMsg -Level INFO -AddToLog

            $ResultsFolderParent = Split-Path -Path $ResultsFolder -Parent
            $ResultsFolderTitle  = (Get-Item -Path $ResultsFolder).Name
            $ArchiveFileName     = "$ResultsFolderTitle.zip"

            Compress-Archive -Path $ResultsFolder -DestinationPath "$ResultsFolderParent\$ArchiveFileName" -Force

            $ExecutionTime = $Stopwatch.Elapsed.TotalSeconds

            Show-Message -File $ArchiveFileName -ExecutionTime "$( $ExecutionTime ) seconds" -Level SUCCESS -AddToLog

            $Stopwatch.Stop()
        }
        catch {
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name ) on $( $ComputerName )'. Error => $( $_.Exception.Message )"
            Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
        }
    }
    end {
        if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    }
}
