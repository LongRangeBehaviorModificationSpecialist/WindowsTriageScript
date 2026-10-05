function Get-ComputerRam {
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
            $BeginMsg = "Starting RAM capture from computer: $( $ComputerName ). Please wait..."
            Show-Message -Message $BeginMsg -Level INFO -AddToLog

            $RamCaptureFolder = Join-Path -Path $ResultsFolder -ChildPath "Ram_Capture"
            $null = New-Item -ItemType Directory -Path $RamCaptureFolder -Force

            # Test-IfExists -FolderName $RamCaptureFolder -Type FOLDER

            $Drive    = New-Object System.IO.DriveInfo ([System.IO.Path]::GetPathRoot($RamCaptureFolder))
            $RamBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory

            if ($Drive.DriveFormat -eq "FAT32") {
                throw "Destination is FAT32 (4 GB file limit); use exFAT or NTFS."
            }
            if ($Drive.AvailableFreeSpace -lt ($RamBytes * 1.1)) {
                throw "Not enough space for a RAM image on $( $Drive.Name )."
            }

            # Start the RAM acquisition from the current machine
            # Start-Process -NoNewWindow -FilePath $Binaries["MagnetRamCapture"] -ArgumentList "/accepteula /go /silent" -Wait
            $P = Start-Process -FilePath (Get-TriageBinary "MagnetRamCapture") -ArgumentList "/accepteula /go /silent" -WorkingDirectory $RamCaptureFolder -NoNewWindow -Wait -PassThru

            $Raw = @(Get-ChildItem -LiteralPath $RamCaptureFolder -Filter *.raw -File)
            if ($P.ExitCode -ne 0 -or -not $Raw) {
                throw "RAM capture failed (exit $( $P.ExitCode ), $( $Raw.Count ) .raw file(s))."
            }


            # Once the RAM has been acquired, move the file to the "RAM" folder
            #TODO -- Double check where the output is written when run from elevated command prompt
            Move-Item -Path .\bin\*.raw -Destination $RamCaptureFolder -Force

            $RamCaptureFileName = (Get-ChildItem -LiteralPath $RamCaptureFolder -Filter "*.raw").Name

            $ExecutionTime = $Stopwatch.Elapsed.TotalSeconds

            $SuccessMsg = "RAM capture completed successfully from computer: $( $ComputerName )"
            Show-Message -Message $SuccessMsg -Level SUCCESS -AddToLog

            Show-Message -File $RamCaptureFileName -ExecutionTime " $ExecutionTime seconds" -Level SUCCESS -AddToLog

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
