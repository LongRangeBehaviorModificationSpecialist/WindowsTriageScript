function Get-ComputerRam {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResultsFolder
    )

    try {
        $Stopwatch    = [System.Diagnostics.Stopwatch]::StartNew()
        $ComputerName = $env:COMPUTERNAME

        $BeginMsg = "Starting RAM capture from computer: $( $ComputerName ). Please wait..."
        Show-Message -Message $BeginMsg -Level INFO -AddToLog

        $RamCaptureFolder = Join-Path -Path $ResultsFolder -ChildPath "Ram_Capture"
        $null             = New-Item -ItemType Directory -Path $RamCaptureFolder -Force

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
        $P = Start-Process `
            -FilePath (Get-TriageBinary "MagnetRamCapture") `
            -ArgumentList "/accepteula /go /silent" `
            -WorkingDirectory $RamCaptureFolder `
            -NoNewWindow -Wait -PassThru

        $Raw = @(Get-ChildItem -LiteralPath $RamCaptureFolder -Filter *.raw -File)
        if ($P.ExitCode -ne 0 -or -not $Raw) {
            throw "RAM capture failed (exit $( $P.ExitCode ), $( $Raw.Count ) .raw file(s))."
        }

        $RamCaptureFileName = (Get-ChildItem -LiteralPath $RamCaptureFolder -Filter "*.raw").Name

        $SuccessMsg = "RAM capture completed successfully from computer => $( $ComputerName )"
        Show-Message -Message $SuccessMsg -Level INFO -AddToLog

        Show-Message -File $RamCaptureFileName -ExecutionTime (Format-TriageDuration -Span $Stopwatch.Elapsed) -Level INFO -AddToLog

        $Stopwatch.Stop()
    }
    catch {
        $Msg = "Execution failed during $( $MyInvocation.MyCommand.Name ) on $( $ComputerName ).  Error => $( $_.Exception.Message )"
        Show-Message -Message $Msg -Level ERROR -AddToLog
    }
    finally {
        if ($Stopwatch.IsRunning) {
            $Stopwatch.Stop()
        }
    }
}
