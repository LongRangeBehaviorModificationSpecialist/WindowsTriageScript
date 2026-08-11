function Invoke-EncryptedDiskDetector {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsFolder
    )

    begin {
        $Stopwatch    = [System.Diagnostics.Stopwatch]::StartNew()
        $ComputerName = $env:computername
        $RunEdd       = Read-Host -Prompt "`n[?] Do you want to run Encrypted Disk Detector on $ComputerName? (y/n)"
    }
    process {
        if ($RunEdd  -eq "y") {
            try {
                $BeginMsg = "Starting Encrypted Disk Detector on: $( $ComputerName )"
                Show-MessageAndWriteLogEntry -Msg $BeginMsg -Level INFO

                $EddResultsFolder = Join-Path -Path $ResultsFolder -ChildPath "Encrypted_Disk_Detector"
                $null             = New-Item -ItemType Directory -Path $EddResultsFolder -Force

                Test-IfExists -FolderName $EddResultsFolder -Type FOLDER

                # Name the file to which the scan results will be saved
                $EddResultsFilePath = Join-Path -Path $EddResultsFolder -ChildPath "encrypted_disk_detector_results.txt"
                $null               = New-Item -ItemType File -Path $EddResultsFilePath -Force
                $EddResultsFileName = [System.IO.Path]::GetFileName($EddResultsFilePath)

                Test-IfExists -FileName $EddResultsFilePath -Type FILE

                # Start the encrypted disk detector executable
                Start-Process -NoNewWindow -FilePath $Binaries["EDD"] -ArgumentList "/batch" -Wait -RedirectStandardOutput $EddResultsFilePath

                $ExecutionTime = $Stopwatch.Elapsed.TotalSeconds

                $SuccessMsg = "Encrypted Disk Detector was run successfully on computer: $( $ComputerName )"
                Show-MessageAndWriteLogEntry -Msg $SuccessMsg -File $EddResultsFileName -ExecutionTime "$( $ExecutionTime ) seconds" -Level SUCCESS

                $Stopwatch.Stop()

                # Read the contents of the EDD text file and show the results on the screen
                Get-Content -Path $EddResultsFilePath -Force
            }
            catch {
                $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error: $( $_.Exception.Message )"
                Show-MessageAndWriteLogEntry -Msg $ErrorMsg -Level ERROR
            }
        }
        elseif ($RunEdd  -eq "n") {
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
