function Get-RunningProcesses {
    <#
    .SYNOPSIS
        Captures the memory of all running processes using Magnet Process
        Capture.

    .DESCRIPTION
        Creates a "Process_Capture" folder inside the results folder and
        runs Magnet Process Capture from the toolkit's verified bin folder
        with `/saveall`, directing its output to that folder.

        The tool creates its own subfolder named
        `MagnetProcessCapture-YYYYMMDD-HHMMSS` and writes one memory dump
        per process into it.

        The function waits for the tool to finish, then logs completion and
        the elapsed time.

        This is different from the 004_Process module, which lists processes,
        services, and drivers as CSV text.

        This function saves process memory itself, which can be very large,
        so use external media with plenty of free space.

    .PARAMETER ResultsFolder
        Path of the case results folder. The Process_Capture subfolder is
        created inside it.

    .INPUTS
        None.

        This function does not accept pipeline input.

    .OUTPUTS
        None.

        Dumps are written to <ResultsFolder>\Process_Capture, and progress is
        written to the screen and the log.

    .EXAMPLE
        Get-RunningProcesses -ResultsFolder "E:\Triage\Case-2026-12345"

        Saves process memory dumps under
        `E:\Triage\Case-2026-12345\Process_Capture`.

    .EXAMPLE
        Invoke-DfirTriageScan -ResultsFolder $Folder -Operator "SA John Doe" `
            -CaseNumber "26-12345" -GetProcesses

        The usual way this function runs: Invoke-DfirTriageScan calls it when
        `-GetProcesses` is given.

    .NOTES
        Requires an elevated (Administrator) session and MagnetProcessCapture
        in the bin folder, verified by `Get-TriageBinary`.

        Completion is reported when the tool exits; its exit code is not
        checked, so look in the Process_Capture folder to confirm that dumps
        were written.

        Errors are logged and do not throw.

    .LINK
        Invoke-DfirTriageScan

    .LINK
        Get-ComputerRam
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

        $StartMsg = "Starting Process Capture from computer [ $( $ComputerName )] . Please wait..."
        Show-Message -Message $StartMsg -Level INFO -AddToLog

        # Make new directory to store the process .dmp files
        $ProcessCaptureFolder = Join-Path -Path $ResultsFolder -ChildPath "Process_Capture"
        $null                 = New-Item -ItemType Directory -Path $ProcessCaptureFolder -Force

        Test-IfExists -FolderName $ProcessCaptureFolder -Type FOLDER

        <#
        Run MAGNETProcessCapture.exe from the \bin directory and save the
        output to the results folder.

        The program will create its own directory to save the results with
        the following naming convention =>
        `MagnetProcessCapture-YYYYMMDD-HHMMSS`
        #>
        Start-Process -NoNewWindow `
            -FilePath (Get-TriageBinary "MagnetProcessCapture") `
            -ArgumentList "/saveall `"$ProcessCaptureFolder`"" `
            -Wait

        Show-Message `
            -Message "Process Capture completed successfully from computer => $( $ComputerName )" `
            -Level INFO `
            -AddToLog

        Show-Message `
            -File $(Split-Path -Path $ProcessCaptureFolder -Leaf) `
            -ExecutionTime (Format-TriageDuration -Span $Stopwatch.Elapsed) `
            -Level INFO `
            -AddToLog

        $Stopwatch.Stop()
    }
    catch {
        $ErrorMsg = "Execution failed during $( $MyInvocation.MyCommand.Name ) on $( $ComputerName ). " +
            "Error => $( $_.Exception.Message )"
        Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
    }
    finally {
        if ($Stopwatch.IsRunning) {
            $Stopwatch.Stop()
        }
    }
}
