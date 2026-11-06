function Invoke-CaseArchive {
    <#
    .SYNOPSIS
        Compresses the results folder into a ZIP file and records the ZIP's
        SHA256 hash.

    .DESCRIPTION
        Creates "<results folder name>.zip" in the folder that contains the
        results folder (so the archive is not inside the data it holds).
        Every file under the results folder is added, except files under the
        folders listed in ExcludeFolders, using optimal compression. Inside
        the ZIP, each file is stored under a top-level folder named after
        the results folder.

        The function refuses to run if the ZIP already exists.  A file that
        cannot be added (for example, one that is locked) is reported as an
        error and skipped; the rest of the archive is still built.

        After building the ZIP, the function re-opens it and compares the
        number of entries with the number of files it added; a mismatch is
        treated as a failure.  It then computes the SHA256 hash of the ZIP
        and writes a sidecar file, "<zip name>.sha256", next to it in the
        format "HASH *filename".  The sidecar is outside the archive so that
        it can be used to check the archive.

        Run this after the log has been closed and hashed (`Close-TriageLog`),
        so the archived log is final.

        Messages are shown on screen only, not added to the log, for the same
        reason.

    .PARAMETER ResultsFolder
        Path of the case results folder to archive.  It must exist.

    .PARAMETER ExcludeFolders
        Folders to leave out, given relative to the results folder (for
        example `Ram_Capture`).  A file is skipped when its path starts
        with one of these folders.  Defaults to the `ArchiveExcludeFolders`
        value in `TriageConfig.psd1`, which is normally used to keep very
        large items such as RAM images and raw NTFS files out of the ZIP.

    .INPUTS
        None.

        This function does not accept pipeline input.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        On success, an object with these properties:
            ZipPath   Full path of the ZIP file.
            Sha256    SHA256 hash of the ZIP file.
            Excluded  The exclusion list that was applied.

        On failure, an error message is shown and nothing is returned.

    .EXAMPLE
        Invoke-CaseArchive -ResultsFolder "E:\Triage\Case-2026-12345"

        Creates `E:\Triage\Case-2026-12345.zip` and
        `E:\Triage\Case-2026-12345.zip.sha256`, leaving out the folders named
        in the configuration file.

    .EXAMPLE
        $Archive = Invoke-CaseArchive -ResultsFolder `
            $global:ResultsFolder -ExcludeFolders "Ram_Capture" `
            "{0} => {1}" -f (Split-Path $Archive.ZipPath -Leaf), `
            $Archive.Sha256

        Archives everything except the RAM image folder and displays the
        hash to record in the case notes.

    .NOTES
        If the function fails after it has created the ZIP, a partial file
        may remain on disk.  Delete it before retrying, because the function
        will not overwrite an existing archive.

        Failures are shown with Show-Message and do not throw, so check
        whether the return value is `$null`.

        Ensure the destination drive has enough free space for the compressed data.

    .LINK
        Close-TriageLog

    .LINK
        Get-StreamHash
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResultsFolder,

        [string[]]$ExcludeFolders = (Get-TriageConfig).Defaults.ArchiveExcludeFolders
    )

    try {
        $Stopwatch    = [System.Diagnostics.Stopwatch]::StartNew()
        $ComputerName = $env:COMPUTERNAME
        $Zip = $null

        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        $Root    = (Resolve-Path -LiteralPath $ResultsFolder).Path.TrimEnd("\")
        $Name    = Split-Path -Path $Root -Leaf
        $ZipPath = Join-Path -Path (Split-Path -Path $Root -Parent) -ChildPath "$Name.zip"

        if (Test-Path -LiteralPath $ZipPath) {
            throw "Archive already exists [ $ZipPath ]"
        }

        $CreateMsg = "Creating case archive => $Name.zip; excluding: [ $( $ExcludeFolders -join ', ' ) ]"
        Show-Message -Message $CreateMsg -Level INFO -AddToLog

        $Skip  = @(
            $ExcludeFolders |
            ForEach-Object {
                (Join-Path -Path $Root -ChildPath $_) + "\"
            }
        )
        $Files = @(
            Get-ChildItem -LiteralPath $Root -Recurse -Force -File |
            Where-Object {
                $Path = $_.FullName
                -not ($Skip | Where-Object {
                    $Path.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase)
                })
            }
        )

        $Zip   = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        $Added = 0
        foreach ($File in $Files) {
            $Rel = $File.FullName.Substring($Root.Length + 1).Replace("\", "/")
            try {
                [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $Zip,
                    $File.FullName,
                    "$Name/$Rel",
                    [System.IO.Compression.CompressionLevel]::Optimal
                )
                $Added++
            }
            catch {
                Show-Message -Message "Not added to archive [ $Rel ] => $( $_.Exception.Message )" `
                    -Level ERROR -AddToLog
            }
        }
        $Zip.Dispose()
        $Zip = $null

        # Sanity check => re-open and count entries
        $Check = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)

        try {
            $Entries = $Check.Entries.Count
        }
        finally {
            $Check.Dispose()
        }

        if ($Entries -ne $Added) {
            throw "Archive holds $Entries entries but $Added files were added."
        }

        # Hash the zip and write a sidecar file next to it (outside of the archive)
        $Sha = (Get-StreamHash -LiteralPath $ZipPath -IncludeMd5:$false).SHA256
        "$Sha *$(Split-Path -Path $ZipPath -Leaf )" |
            Set-Content -LiteralPath "$ZipPath.sha256" -Encoding ASCII

        $CompleteMsg = "Archive complete => $Added files in $( [int]$Stopwatch.Elapsed.TotalSeconds )s."
        Show-Message -Message $CompleteMsg -Level INFO

        [PSCustomObject]@{
            ZipPath  = $ZipPath
            Sha256   = $Sha
            Excluded = $ExcludeFolders
        }
    }
    catch {
        $Msg = "Execution failed during $( $MyInvocation.MyCommand.Name ) on $( $ComputerName ). " +
            "Error => $( $_.Exception.Message )"
        Show-Message -Message $Msg -Level ERROR
    }
    finally {
        if ($Zip) {
            $Zip.Dispose()
        }
        if ($Stopwatch.IsRunning) {
            $Stopwatch.Stop()
        }
    }
}
