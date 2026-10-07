function Invoke-EDD {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ResultsFolder
    )

    begin {
        $Stopwatch    = [System.Diagnostics.Stopwatch]::StartNew()
        $ComputerName = $env:COMPUTERNAME
    }
    process {
        try {
            $BeginMsg = "Starting Encrypted Disk Detector on [ $( $ComputerName ) ]"
            Show-Message -Message $BeginMsg -Level INFO -AddToLog

            $EddResultsFolder = Join-Path -Path $ResultsFolder -ChildPath "EDD"
            $null = New-Item -ItemType Directory -Path $EddResultsFolder -Force

            Test-IfExists -FolderName $EddResultsFolder -Type FOLDER

            # Name the file to which the scan results will be saved
            $EddResultsFilePath = Join-Path -Path $EddResultsFolder -ChildPath "edd_results.txt"
            $null               = New-Item -ItemType File -Path $EddResultsFilePath -Force
            $EddResultsFileName = [System.IO.Path]::GetFileName($EddResultsFilePath)

            Test-IfExists -FileName $EddResultsFilePath -Type FILE

            # Run the executable
            Start-Process -NoNewWindow `
                -FilePath (Get-TriageBinary "EDD") `
                -ArgumentList "/batch" `
                -Wait `
                -RedirectStandardOutput $EddResultsFilePath

            # $ExecutionTime = $Stopwatch.Elapsed.TotalSeconds

            $Stopwatch.Stop()

            # Read the contents of the EDD text file and show the results on the screen
            $EddResults = (Get-Content -Path $EddResultsFilePath -Force) -join "`r`n"

            # Guard against an empty result file
            if ([string]::IsNullOrWhiteSpace($EddResults)) {
                $EddResults = "(EDD produced no output => check if the tool ran interactively)"
            }

            Write-LogMessage -Message $EddResults

            # Show-Message -Message "Encrypted Disk Detector was run successfully on computer [ $( $ComputerName ) ]" -File $EddResultsFileName -ExecutionTime (Format-TriageDuration -Span $Stopwatch.Elapsed) -Level INFO -AddToLog
            Show-Message -File $EddResultsFileName -ExecutionTime (Format-TriageDuration -Span $Stopwatch.Elapsed) -Level INFO -AddToLog
        }
        catch {
            Show-Message -Message "Execution failed during $( $MyInvocation.MyCommand.Name ) on $( $ComputerName ).  Error => $( $_.Exception.Message )" -Level ERROR -AddToLog
        }
    }
    end {
        if ($Stopwatch.IsRunning) {
            $Stopwatch.Stop()
        }
    }
}
