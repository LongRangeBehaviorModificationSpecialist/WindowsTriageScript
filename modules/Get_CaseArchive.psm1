function Get-CaseArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ResultsFolder,
        [string[]]$ExcludeFolders = (Get-TriageConfig).Defaults.ArchiveExcludeFolders
    )

    begin {
        $Stopwatch    = [System.Diagnostics.Stopwatch]::StartNew()
        $ComputerName = $env:COMPUTERNAME
    }
    process {
        $Zip = $null
        try {
            Add-Type -AssemblyName System.IO.Compression
            Add-Type -AssemblyName System.IO.Compression.FileSystem

            $Root = (Resolve-Path -LiteralPath $ResultsFolder).Path.TrimEnd("\")
            $Name = Split-Path $Root -Leaf
            $ZipPath = Join-Path -Path (Split-Path $Root -Parent) -ChildPath "$Name.zip"

            if (Test-Path -LiteralPath $ZipPath) {
                throw "Archive already exists => $ZipPath"
            }

            Show-Message -Message "Creating case archive => $Name.zip; excluding: [ $( $ExcludeFolders -join ', ' ) ]" -Level INFO

            $Skip = @($ExcludeFolders | ForEach-Object { (Join-Path -Path $Root -ChildPath $_) + "\" })
            $Files = @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Where-Object {
                $Path = $_.FullName
                -not ($Skip | Where-Object { $Path.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) })
            })

            $Zip = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
            $Added = 0
            foreach ($F in $Files) {
                $Rel = $F.FullName.Substring($Root.Length + 1).Replace("\", "/")
                try {
                    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Zip, $F.FullName, "$Name/$Rel", [System.IO.Compression.CompressionLevel]::Optimal)
                    $Added++
                }
                catch {
                    Show-Message -Message "Not added to archive => $Rel => $( $_.Exception.Message )" -Level ERROR
                }
            }
            $Zip.Dispose(); $Zip = $null

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

            # Hash the zip and write a sidecar file next to it (outside of
            # the archive)
            $Sha = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash
            "$Sha *$( Split-Path $ZipPath -Leaf )" | Set-Content -LiteralPath "$ZipPath.sha256" -Encoding ASCII

            Show-Message -Message "Archive complete => $Added files in $( [int]$Stopwatch.Elapsed.TotalSeconds )s." -Level INFO

            [pscustomobject]@{
                ZipPath = $ZipPath;
                Sha256 = $Sha;
                Excluded = $ExcludeFolders
            }
        }
        catch {
            Show-Message -Message "Execution failed during $( $MyInvocation.MyCommand.Name ) on $( $ComputerName ).  Error => $( $_.Exception.Message )" -Level ERROR
        }
        finally {
            if ($Zip) { $Zip.Dispose() }
        }
    }
    end {
        if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    }
}
