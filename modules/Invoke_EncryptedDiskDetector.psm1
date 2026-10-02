function Invoke-EncryptedDiskDetector {
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
            $BeginMsg = "Starting Encrypted Disk Detector on: $( $ComputerName )"
            Show-Message -Message $BeginMsg -Level INFO -AddToLog

            $EddResultsFolder = Join-Path -Path $ResultsFolder -ChildPath "Encrypted_Disk_Detector"
            $null = New-Item -ItemType Directory -Path $EddResultsFolder -Force

            Test-IfExists -FolderName $EddResultsFolder -Type FOLDER

            # Name the file to which the scan results will be saved
            $EddResultsFilePath = Join-Path -Path $EddResultsFolder -ChildPath "encrypted_disk_detector_results.txt"
            $null               = New-Item -ItemType File -Path $EddResultsFilePath -Force
            $EddResultsFileName = [System.IO.Path]::GetFileName($EddResultsFilePath)

            Test-IfExists -FileName $EddResultsFilePath -Type FILE

            # Start the encrypted disk detector executable
            Start-Process -NoNewWindow `
                -FilePath $global:Binaries["EDD"] `
                -ArgumentList "/batch" `
                -Wait `
                -RedirectStandardOutput $EddResultsFilePath

            $ExecutionTime = $Stopwatch.Elapsed.TotalSeconds

            $Stopwatch.Stop()

            # Read the contents of the EDD text file and show the results
            # on the screen
            $EddResults = (Get-Content -Path $EddResultsFilePath -Force) -join "`r`n"

            # Guard against an empty result file
            if ([string]::IsNullOrWhiteSpace($EddResults)) {
                $EddResults = "(EDD produced no output -- check if the tool ran interactively)"
            }

            Write-LogMessage -Message $EddResults

            $SuccessMsg = "Encrypted Disk Detector was run successfully on computer: '$( $ComputerName )'"
            Show-Message -Message $SuccessMsg -File $EddResultsFileName -ExecutionTime "$( $ExecutionTime ) seconds" -Level SUCCESS -AddToLog
        }
        catch {
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )' on $( $ComputerName ). Error => $( $_.Exception.Message )"
            Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
        }
    }
    end {
        if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    }
}
