function Get-RunningProcesses {
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
            Show-Message -Message "Starting Process Capture from computer => $( $ComputerName ). Please wait..." -Level INFO -AddToLog

            # Make new directory to store the process .dmp files
            $ProcessCaptureFolder = Join-Path -Path $ResultsFolder -ChildPath "Process_Capture"
            $null = New-Item -ItemType Directory -Path $ProcessCaptureFolder -Force

            Test-IfExists -FolderName $ProcessCaptureFolder -Type FOLDER

            <#
            Run MAGNETProcessCapture.exe from the \bin directory and save the
            output to the results folder.

            The program will create its own directory to save the results with
            the following naming convention =>
            `MagnetProcessCapture-YYYYMMDD-HHMMSS`
            #>
            Start-Process -NoNewWindow -FilePath (Get-TriageBinary "MagnetProcessCapture") -ArgumentList "/saveall `"$ProcessCaptureFolder`"" -Wait

            $ExecutionTime = $Stopwatch.Elapsed.TotalSeconds

            Show-Message -Message "Process Capture completed successfully from computer => $( $ComputerName )" -Level SUCCESS -AddToLog

            Show-Message -File $(Split-Path -Path $ProcessCaptureFolder -Leaf) -ExecutionTime "$( $ExecutionTime ) seconds" -Level SUCCESS -AddToLog

            $Stopwatch.Stop()
        }
        catch {
            Show-Message -Message "Execution failed during $( $MyInvocation.MyCommand.Name ) on $( $ComputerName ).  Error => $( $_.Exception.Message )" -Level ERROR -AddToLog
        }
    }
    end {
        if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    }
}
