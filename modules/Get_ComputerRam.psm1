function Get-ComputerRam {
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
            $BeginMsg = "Starting RAM capture from computer: $( $ComputerName ). Please wait..."
            Show-Message -Message $BeginMsg -Level INFO -AddToLog

            $RamCaptureFolder = Join-Path -Path $ResultsFolder -ChildPath "Ram_Capture"
            $null = New-Item -ItemType Directory -Path $RamCaptureFolder -Force

            Test-IfExists -FolderName $RamCaptureFolder -Type FOLDER

            # Start the RAM acquisition from the current machine
            Start-Process -NoNewWindow -FilePath $Binaries["MagnetRamCapture"] -ArgumentList "/accepteula /go /silent" -Wait

            # Once the RAM has been acquired, move the file to the 'RAM' folder
            Move-Item -Path .\bin\*.raw -Destination $RamCaptureFolder -Force

            $RamCaptureFileName = (Get-ChildItem -Path $RamCaptureFolder -Filter "*.raw").Name

            $ExecutionTime = $Stopwatch.Elapsed.TotalSeconds

            $SuccessMsg = "RAM capture completed successfully from computer: $( $ComputerName )"
            Show-Message -Message $SuccessMsg -Level SUCCESS -AddToLog

            Show-Message -File $RamCaptureFileName -ExecutionTime " $ExecutionTime seconds" -Level SUCCESS -AddToLog

            $Stopwatch.Stop()
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
