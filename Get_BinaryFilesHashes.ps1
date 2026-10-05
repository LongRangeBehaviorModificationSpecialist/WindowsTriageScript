function Get-BinaryFilesHashes {
    <#
    .SYNOPSIS
        Helper function used to create a JSON file containing the hash values
        of the files in the .\bin directory.

        Copy this function to a separate .ps1 file and run it after new files
        are added to the .\bin directory.

        The triage program does not rely on this function.  This function
        does not need to be added to the `FunctionsToExport` array in the
        `triage.psd1` file.

        It is saved here to make it easier to find in the future.
    #>
    $Folder = Join-Path -Path (Get-Location) -ChildPath "bin"
    $Root   = (Resolve-Path $Folder).Path

    $Files = Get-ChildItem -LiteralPath $Root -File -Recurse | Where-Object { $_.Name -ne "__hashes.json" }

    # Hash first, so the count reflects what was actually hashed
    $Entries = @(foreach ($F in $Files) {
        [ordered]@{
            Path        = $F.FullName.Substring($Root.Length).TrimStart("\")
            SHA256      = (Get-FileHash -LiteralPath $F.FullName -Algorithm SHA256).Hash
            Length      = $F.Length
            FileVersion = $F.VersionInfo.FileVersion
        }
    })

    $Manifest = [ordered]@{
        SchemaVersion  = 1
        # OsBuild        = $Build
        Algorithm      = "SHA256"
        FileCount      = $Entries.Count
        CreatedUtc     = (Get-Date).ToUniversalTime().ToString("o")
        SourceComputer = $env:COMPUTERNAME
        Files          = $Entries
    }

    $Manifest | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path -Path $Root -ChildPath "__hashes.json") -Encoding UTF8

    Write-Host "Function run succesfully..." -ForegroundColor Green
}

Get-BinaryFilesHashes
