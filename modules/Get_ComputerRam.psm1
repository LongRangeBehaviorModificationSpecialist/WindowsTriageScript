function Get-ComputerRam {
    <#
    .SYNOPSIS
        Captures the computer's physical memory to a `.raw` file using Magnet
        RAM Capture.

    .DESCRIPTION
        Creates a `Ram_Capture` folder inside the results folder and runs
        Magnet RAM Capture from the toolkit's verified bin folder, with
        `/accepteula /go /silent`, using that folder as its working directory
        so the image is written there.

        The function waits for the tool to finish.

        Before starting, it makes two safety checks and stops with an error
        if either fails:

            The destination drive must not be FAT32 (a 4 GB file limit makes
            a RAM image impossible).

            The destination drive must have free space of at least 110 percent
            of the installed RAM.

        After the tool exits, the function confirms that the exit code is 0
        and that at least one .raw file exists in the folder.

        It then logs success and the elapsed time.  The image is hashed later,
        together with all other evidence, by `Get-FileHashes`.

        A RAM image is the largest item the toolkit produces and is by far
        the most volatile, so the output folder should be on external NTFS
        or exFAT media, not the computer being examined.

    .PARAMETER ResultsFolder
        Path of the case results folder.

        The `Ram_Capture` subfolder is created inside it.

    .INPUTS
        None.

        This function does not accept pipeline input.

    .OUTPUTS
        None.

        The image is written to `<ResultsFolder>\Ram_Capture`, and progress is
        written to the screen and the log.

    .EXAMPLE
        Get-ComputerRam -ResultsFolder "E:\Triage\Case-2026-12345"

        Captures memory to E:\Triage\Case-2026-12345\Ram_Capture\*.raw.

    .EXAMPLE
        Invoke-DfirTriageScan -ResultsFolder $Folder -Operator "SA John Doe" `
            -CaseNumber "26-12345" -CaptureRam

        The usual way this function runs: Invoke-DfirTriageScan calls it
        when the `-CaptureRam` argument is given.

    .NOTES
        Requires an elevated (Administrator) session and MagnetRamCapture in
        the bin folder, verified by `Get-TriageBinary`.

        Memory acquisition tools typically load a kernel driver temporarily,
        which is an unavoidable change to the examined computer; record it in
        the case notes.

        Errors are logged and do not throw, so check the log and the
        `Ram_Capture` folder after the run.

    .LINK
        Invoke-DfirTriageScan

    .LINK
        Get-TriageBinary
    #>
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

        Show-Message `
            -File $RamCaptureFileName `
            -ExecutionTime (Format-TriageDuration -Span $Stopwatch.Elapsed) `
            -Level INFO `
            -AddToLog

        $Stopwatch.Stop()
    }
    catch {
        $Msg = "Execution failed during $( $MyInvocation.MyCommand.Name ) on $( $ComputerName ). " +
            "Error => $( $_.Exception.Message )"
        Show-Message -Message $Msg -Level ERROR -AddToLog
    }
    finally {
        if ($Stopwatch.IsRunning) {
            $Stopwatch.Stop()
        }
    }
}
