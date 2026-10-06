function Get-StreamHash {
    # Reads the file once and feeds both algorithms from the same buffer.
    param(
        [Parameter(Mandatory)][string]$LiteralPath,
        [bool]$IncludeMd5 = (Get-TriageConfig).Defaults.HashIncludeMd5
    )
    $Sha = [System.Security.Cryptography.SHA256]::Create()
    $Md5 = if ($IncludeMd5) { [System.Security.Cryptography.MD5]::Create() }
    $Fs  = $null
    try {
        $Fs = [System.IO.File]::Open($LiteralPath, [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $Buffer = New-Object byte[] 1048576
        while (($Read = $Fs.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
            [void]$Sha.TransformBlock($Buffer, 0, $Read, $null, 0)
            if ($Md5) { [void]$Md5.TransformBlock($Buffer, 0, $Read, $null, 0) }
        }
        [void]$Sha.TransformFinalBlock($Buffer, 0, 0)
        if ($Md5) { [void]$Md5.TransformFinalBlock($Buffer, 0, 0) }

        [pscustomobject]@{
            SHA256 = [System.BitConverter]::ToString($Sha.Hash).Replace("-", "")
            MD5    = if ($Md5) { [System.BitConverter]::ToString($Md5.Hash).Replace("-", "") } else { $null }
        }
    }
    finally {
        if ($Fs) { $Fs.Dispose() }
        $Sha.Dispose()
        if ($Md5) { $Md5.Dispose() }
    }
}


function Get-FileHashes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ResultsFolder,
        [bool]$IncludeMd5 = $true,
        [string[]]$ExcludedFiles = @(
            "*PowerShell_transcript*",
            "*Hash_Values*"
        )
    )

    begin {
        $Stopwatch    = [System.Diagnostics.Stopwatch]::StartNew()
        $ComputerName = $env:COMPUTERNAME
    }

    process {
        try {
            $Root       = (Resolve-Path -LiteralPath $ResultsFolder).Path.TrimEnd("\")
            $LogsDir    = Join-Path -Path $Root -ChildPath "Logs"
            $HashFolder = Join-Path -Path $Root -ChildPath "Hash_Results"
            $null       = New-Item -ItemType Directory -Path $HashFolder -Force
            $OutFile    = Join-Path -Path $HashFolder -ChildPath "$( Split-Path $Root -Leaf )_hash_values.csv"

            if ($IncludeMd5) {
                try { [System.Security.Cryptography.MD5]::Create().Dispose() }
                catch {
                    $IncludeMd5 = $false
                    Show-Message -Message "MD5 is unavailable here (FIPS mode?). Hashing SHA-256 only." -Level WARNING -AddToLog
                }
            }

            # Everything except the log folder and the hash output folder
            $Files = @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Where-Object {
                -not $_.FullName.StartsWith("$LogsDir\", [System.StringComparison]::OrdinalIgnoreCase) -and
                -not $_.FullName.StartsWith("$HashFolder\", [System.StringComparison]::OrdinalIgnoreCase)
            })
            Show-Message -Message "Hashing $( $Files.Count ) files (log files are hashed when the log is closed)..." -Level INFO -AddToLog

            $Rows = foreach ($File in $Files) {
                $Sha = $null; $Md5 = $null; $Err = ""
                try {
                    $H   = Get-StreamHash -LiteralPath $File.FullName -IncludeMd5:$IncludeMd5
                    $Sha = $H.SHA256
                    $Md5 = $H.MD5
                }
                catch {
                    $Err = $_.Exception.Message
                    Show-Message -Message "Could not hash => $( $File.FullName ) => $Err" -Level ERROR -AddToLog
                }
                [pscustomobject]@{
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
            Show-Message -Message "Hashed $( $Files.Count ) files" -ExecutionTime (Format-TriageDuration -Span $Stopwatch.Elapsed) -Level SUCCESS -AddToLog
        }
        catch {
            Show-Message -Message "Execution failed during $( $MyInvocation.MyCommand.Name ) on $( $ComputerName ).  Error => $( $_.Exception.Message )" -Level ERROR -AddToLog
        }
    }
    end {
        if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    }
}


function Close-TriageLog {
    <#
    .SYNOPSIS
        Stops all writes to the log, then hashes everything in Logs\ plus the
        evidence hash CSV into `Hash_Results\final_hashes.csv`.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ResultsFolder
    )

    $Root       = (Resolve-Path -LiteralPath $ResultsFolder).Path.TrimEnd("\")
    $LogsDir    = Join-Path -Path $Root -ChildPath "Logs"
    $HashFolder = Join-Path -Path $Root -ChildPath "Hash_Results"

    $LogPath        = $global:LogFile
    # Show-Message now prints to the console only
    $global:LogFile = $null

    $Targets = @(Get-ChildItem -LiteralPath $LogsDir -Recurse -Force -File) +
            @(Get-ChildItem -LiteralPath $HashFolder -Filter "*_hash_values.csv" -File)

    $Rows = foreach ($F in $Targets) {
        [pscustomobject]@{
            RelativePath = $F.FullName.Substring($Root.Length + 1)
            SizeBytes    = $F.Length
            SHA256       = (Get-FileHash -LiteralPath $F.FullName -Algorithm SHA256).Hash
        }
    }
    $FinalFile = Join-Path -Path $HashFolder -ChildPath "final_hashes.csv"
    $Rows | Export-Csv -LiteralPath $FinalFile -NoTypeInformation -Encoding UTF8

    [pscustomobject]@{
        LogFile           = $LogPath
        FinalHashesFile   = $FinalFile
        FinalHashesSha256 = (Get-FileHash -LiteralPath $FinalFile -Algorithm SHA256).Hash
    }
}