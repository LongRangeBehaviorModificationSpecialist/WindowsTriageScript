function Get-StreamHash {
    <#
    .SYNOPSIS
        Calculates SHA256 and optionally MD5 hashes for a file in a single
        read pass.

    .DESCRIPTION
        Opens a file stream with sequential scan optimization and reads it
        in 1MB chunks.

        Each data block is fed simultaneously into both the SHA256 and MD5
        cryptographic hash algorithms, minimizing disk I/O overhead.

    .PARAMETER LiteralPath
        The literal path to the file that will be hashed.

        Wildcards are not supported.

    .PARAMETER IncludeMd5
        A boolean switch determining whether to calculate an MD5 hash
        alongside the SHA256 hash.

        Defaults to the value specified in
        `(Get-TriageConfig).Defaults.HashIncludeMd5`.

    .EXAMPLE
        Get-StreamHash -LiteralPath "C:\Evidence\file.bin" -IncludeMd5 $true

        Calculates both SHA256 and MD5 hashes for the specified file and
        returns a custom object.

    .INPUTS
        None

        This function does not accept pipeline input.

    .OUTPUTS
        System.Management.Automation.PSCustomObject with the following
        properties:

            SHA256  -   Uppercase hexadecimal string of the SHA256 hash.

            MD5     -   Uppercase hexadecimal string of the MD5 hash (or
                        $null if omitted).

    .NOTES
        The file is opened with shared read/write access and automatically
        disposed in a `finally` block regardless of success or failure.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LiteralPath,

        [bool]$IncludeMd5 = (Get-TriageConfig).Defaults.HashIncludeMd5
    )

    $Sha = [System.Security.Cryptography.SHA256]::Create()
    $Md5 = if ($IncludeMd5) {
        [System.Security.Cryptography.MD5]::Create()
    }
    $Fs  = $null

    try {
        $Fs = [System.IO.FileStream]::New($LiteralPath, [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite,
                1048576, [System.IO.FileOptions]::SequentialScan)
        $Buffer = New-Object byte[] 1048576
        while (($Read = $Fs.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
            [void]$Sha.TransformBlock($Buffer, 0, $Read, $null, 0)
            if ($Md5) {
                [void]$Md5.TransformBlock($Buffer, 0, $Read, $null, 0)
            }
        }

        [void]$Sha.TransformFinalBlock($Buffer, 0, 0)

        if ($Md5) {
            [void]$Md5.TransformFinalBlock($Buffer, 0, 0)
        }

        [PSCustomObject]@{
            SHA256 = [System.BitConverter]::ToString($Sha.Hash).Replace("-", "")
            MD5    = if ($Md5) {
                [System.BitConverter]::ToString($Md5.Hash).Replace("-", "")
            }
            else {
                $null
            }
        }
    }
    finally {
        if ($Fs) {
            $Fs.Dispose()
        }
        $Sha.Dispose()
        if ($Md5) {
            $Md5.Dispose()
        }
    }
}

function Get-FileHashes {
    <#
    .SYNOPSIS
        Recursively hashes files within a triage results folder and exports
        the report to CSV.

    .DESCRIPTION
        Scans the specified results directory recursively while excluding
        log folders and previous hash directories.

        It utilizes `Get-StreamHash` to calculate file hashes in a single
        pass, gathers metadata (sizes, UTC timestamps, attributes), and
        handles FIPS fallback scenarios for MD5.

        Results are written out to a CSV file inside the `Hash_Results`
        subfolder.

    .PARAMETER ResultsFolder
        The root path of the triage results folder containing the files to
        be hashed.

    .PARAMETER IncludeMd5
        Indicates whether to include MD5 hash calculation.

        Defaults to $true (subject to FIPS compliance checks).

    .PARAMETER ExcludedFiles
        An array of file patterns or filters to exclude from the hashing
        process.

        Defaults to transcripts and existing hash value files.

    .EXAMPLE
        Get-FileHashes -ResultsFolder "D:\TriageOutput" -IncludeMd5 $true

        Hashes all eligible files in "D:\TriageOutput", logs progress, and
        saves the CSV report.

    .INPUTS
        None.

        This function does not accept pipeline input directly.

    .OUTPUTS
        None.

        Writes progress messages to logging/console and generates a CSV
        report on disk.

    .NOTES
        Measures execution time using a Stopwatch and logs errors individually
        if individual files fail to hash.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResultsFolder,

        [bool]$IncludeMd5 = $true,

        [string[]]$ExcludedFiles = @(
            "*PowerShell_transcript*",
            "*Hash_Values*"
        )
    )

    $Stopwatch    = [System.Diagnostics.Stopwatch]::StartNew()
    $ComputerName = $env:COMPUTERNAME

    try {
        $Root       = (Resolve-Path -LiteralPath $ResultsFolder).Path.TrimEnd("\")
        $LogsDir    = Join-Path -Path $Root -ChildPath "Logs"
        $HashFolder = Join-Path -Path $Root -ChildPath "Hash_Results"
        $null       = New-Item -ItemType Directory -Path $HashFolder -Force
        $OutFile    = (
            Join-Path -Path $HashFolder -ChildPath "$( Split-Path -Path $Root -Leaf )_hash_values.csv"
        )

        if ($IncludeMd5) {
            try {
                [System.Security.Cryptography.MD5]::Create().Dispose()
            }
            catch {
                $IncludeMd5 = $false
                Show-Message -Message "MD5 is unavailable here (FIPS mode?). Hashing SHA-256 only." `
                    -Level WARNING -AddToLog
            }
        }

        # Everything except the log folder and the hash output folder
        $Files = @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Where-Object {
            -not $_.FullName.StartsWith("$LogsDir\", [System.StringComparison]::OrdinalIgnoreCase) -and
            -not $_.FullName.StartsWith("$HashFolder\", [System.StringComparison]::OrdinalIgnoreCase)
        })
        Show-Message -Message "Hashing $( $Files.Count ) files (log files are hashed when the log is closed)..." `
            -Level INFO -AddToLog

        $Rows = foreach ($File in $Files) {
            $Sha = $null
            $Md5 = $null
            $Err = ""

            try {
                $Hash = Get-StreamHash -LiteralPath $File.FullName -IncludeMd5:$IncludeMd5
                $Sha  = $Hash.SHA256
                $Md5  = $Hash.MD5
            }
            catch {
                $Err = $_.Exception.Message
                Show-Message -Message "Could not hash => $( $File.FullName ) => $Err" `
                    -Level ERROR -AddToLog
            }

            [PSCustomObject]@{
                RelativePath      = $File.FullName.Substring($Root.Length + 1)
                SizeBytes         = $File.Length
                SHA256            = $Sha
                MD5               = $Md5
                CreationTimeUTC   = $File.CreationTimeUtc.ToString("o")
                LastWriteTimeUTC  = $File.LastWriteTimeUtc.ToString("o")
                LastAccessTimeUTC = $File.LastAccessTimeUtc.ToString("o")
                Attributes        = $File.Attributes
                Error             = $Err
            }
        }
        Write-OutputToCsv -Data $Rows -OutputFile $OutFile
        Show-Message -Message "Hashed $( $Files.Count ) files" -ExecutionTime `
            (Format-TriageDuration -Span $Stopwatch.Elapsed) -Level INFO -AddToLog
    }
    catch {
        $ErrorMsg = "Execution failed during $( $MyInvocation.MyCommand.Name ) on " +
            "$( $ComputerName ).  Error => $( $_.Exception.Message )"
        Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
    }
    finally {
        if ($Stopwatch.IsRunning) {
            $Stopwatch.Stop()
        }
    }
}

function Close-TriageLog {
    <#
    .SYNOPSIS
        Finalizes the triage session by closing logs and generating final
        integrity hashes.

    .DESCRIPTION
        Stops active logging writes, flushes and closes the triage log
        writer, and computes SHA256 hashes for all accumulated log files and
        intermediate hash CSVs.

        It outputs a comprehensive final CSV report named `final_hashes.csv`
        under the `Hash_Results` directory and returns a status summary
        object.

    .PARAMETER ResultsFolder
        The root directory path of the active triage session.

    .EXAMPLE
        Close-TriageLog -ResultsFolder "D:\TriageOutput"

        Closes logs, hashes all log and report files, writes
        `final_hashes.csv`, and returns the session summary object.

    .INPUTS
        None.

        This function does not accept pipeline input.

    .OUTPUTS
        System.Management.Automation.PSCustomObject with the following
        properties:

            LogFile             -   Path to the closed log file.
            FinalHashesFile     -   Path to the generated `final_hashes.csv`
                                    file.
            FinalHashesSha256   -   SHA256 hash value of the final hashes
                                    file itself.

    .NOTES
        Modifies global state by clearing `$global:LogFile` to restrict
        subsequent messages to console output only.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsFolder
    )

    $Root       = (Resolve-Path -LiteralPath $ResultsFolder).Path.TrimEnd("\")
    $LogsDir    = Join-Path -Path $Root -ChildPath "Logs"
    $HashFolder = Join-Path -Path $Root -ChildPath "Hash_Results"

    $LogPath        = $global:LogFile
    # Show-Message now prints to the console only
    $global:LogFile = $null

    Close-TriageLogWriter

    $Targets = @(
            Get-ChildItem `
                -LiteralPath $LogsDir `
                -Recurse `
                -Force `-File
        ) +
            @(
                Get-ChildItem `
                    -LiteralPath $HashFolder `
                    -Filter "*_hash_values.csv" `
                    -File
            )

    $Rows = foreach ($F in $Targets) {
        [PSCustomObject]@{
            RelativePath = $F.FullName.Substring($Root.Length + 1)
            SizeBytes    = $F.Length
            SHA256       = (Get-StreamHash `
                                -LiteralPath $F.FullName `
                                -IncludeMd5:$false).SHA256
        }
    }

    $FinalFile = Join-Path -Path $HashFolder -ChildPath "final_hashes.csv"
    $Rows | Export-Csv -LiteralPath $FinalFile -NoTypeInformation -Encoding UTF8

    [PSCustomObject]@{
        LogFile           = $LogPath
        FinalHashesFile   = $FinalFile
        FinalHashesSha256 = (Get-StreamHash `
                                -LiteralPath $FinalFile `
                                -IncludeMd5:$false).SHA256
    }
}
