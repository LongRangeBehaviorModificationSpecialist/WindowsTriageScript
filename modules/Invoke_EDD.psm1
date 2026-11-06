function Invoke-EDD {
    <#
    .SYNOPSIS
        Runs Encrypted Disk Detector (EDD) and saves its report to the
        results folder.

    .DESCRIPTION
        Creates an "EDD" folder inside the results folder, and an empty
        `edd_results.txt` in it.

        Runs EDD from the toolkit's verified bin folder with /batch, so it
        runs without prompting, and redirects its standard output to
        `edd_results.txt`.

        The function waits for the tool to finish.

        The report is then read and written into the log with
        `Write-LogMessage` (log only, not the screen), so the finding is part
        of the permanent record. If EDD produced no output, a placeholder
        line saying so is written to the log instead; the file itself is left
        as the tool wrote it.

        Finally, the file name and elapsed time are logged.

        EDD checks for encrypted volumes and containers, such as BitLocker
        and VeraCrypt.

        Knowing this before the computer is powered off tells the examiner
        whether a live capture is the only chance to get decrypted data.

    .PARAMETER ResultsFolder
        Path of the case results folder. The EDD subfolder is created
        inside it.

    .INPUTS
        None.

        This function does not accept pipeline input.

    .OUTPUTS
        None.

        The report is written to `<ResultsFolder>\EDD\edd_results.txt`, and
        progress is written to the screen and the log.

    .EXAMPLE
        Invoke-EDD -ResultsFolder "E:\Triage\Case-2026-0142"

        Writes the detector's report to
        `E:\Triage\Case-2026-0142\EDD\edd_results.txt`.

    .EXAMPLE
        Invoke-DfirTriageScan -ResultsFolder $Folder -Operator "J. Smith" `
            -CaseNumber "2026-0142" -RunEdd

        The usual way this function runs: `Invoke-DfirTriageScan` calls it
        when the `-RunEdd` parameter is given.

    .NOTES
        Requires EDD in the bin folder, verified by `Get-TriageBinary`, and
        an elevated session so the tool can read all disks.

        Errors are logged and do not throw.

        The 009_Encryption module separately records BitLocker details
        through the Windows BitLocker commands.

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

        $Stopwatch.Stop()

        # Read the contents of the EDD text file and show the results on the screen
        $EddResults = (Get-Content -Path $EddResultsFilePath -Force) -join "`r`n"

        # Guard against an empty result file
        if ([string]::IsNullOrWhiteSpace($EddResults)) {
            $EddResults = "(EDD produced no output => check if the tool ran interactively)"
        }

        Write-LogMessage -Message $EddResults

        Show-Message `
            -File $EddResultsFileName `
            -ExecutionTime (Format-TriageDuration -Span $Stopwatch.Elapsed) `
            -Level INFO `
            -AddToLog
    }
    catch {
        $ErrorMsg = "Execution failed during $( $MyInvocation.MyCommand.Name ) " +
            "on $( $ComputerName ).  Error => $( $_.Exception.Message )"
        Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
    }
    finally {
        if ($Stopwatch.IsRunning) {
            $Stopwatch.Stop()
        }
    }
}
