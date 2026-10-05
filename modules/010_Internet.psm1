function Get-TriageInternetData {
    [CmdletBinding()]
    param(
        [string]$InternetFolder
    )

    $TempFolder = Join-Path -Path $InternetFolder -ChildPath "temp"
    $null       = New-Item -ItemType Directory -Path $TempFolder

    function Invoke-ScriptBlock {
        param(
            [scriptblock]$Action,
            [string]$FunctionMessage,
            [string]$OutputFile
        )
        try {
            Show-Message -Message $FunctionMessage -Level INFO -AddToLog
            & $Action
            Show-Message -File $OutputFile -Level SUCCESS -AddToLog
        }
        catch {
            Show-Message -Message "Execution failed during $( $MyInvocation.MyCommand.Name ).  Error => $( $_.Exception.Message )" -Level ERROR -AddToLog
        }
    }

    function Get-TempInternetFiles {
        param(
            [string]$OutputFile = "$InternetFolder\temp_internet_files.csv"
            )
        $Cutoff = (Get-Date).AddDays(-5)
        $Data = foreach ($U in $global:TriageUserHives) {
            $Dir = Join-Path -Path $U.ProfilePath -ChildPath "AppData\Local\Microsoft\Windows\INetCache"
            if (-not (Test-Path -LiteralPath $Dir)) { continue }
            Get-ChildItem -LiteralPath $Dir -Recurse -Force -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -gt $Cutoff } |
                Select-Object @{ N = "UserName"; E = { $U.UserName } }, FullName, CreationTimeUtc, LastWriteTimeUtc, Length
        }
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-StoredCookies {
        param(
            [string]$OutputFile = "$InternetFolder\stored_cookies.csv"
        )
        $Data = foreach ($U in $global:TriageUserHives) {
            $Dir = Join-Path -Path $U.ProfilePath -ChildPath "AppData\Local\Microsoft\Windows\INetCookies"
            if (-not (Test-Path -LiteralPath $Dir)) { continue }
            foreach ($File in Get-ChildItem -LiteralPath $Dir -Recurse -Force -File -ErrorAction SilentlyContinue) {
                Select-String -LiteralPath $File.FullName -Pattern "/" -ErrorAction SilentlyContinue | ForEach-Object {
                    [pscustomobject]@{
                        UserName = $U.UserName;
                        File = $File.Name;
                        Line = $_.Line
                    }
                }
            }
        }
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-TypedUrls {
        param(
            [string]$OutputFile = "$InternetFolder\typed_urls.csv"
        )
        Export-PerUserRegistry -OutputFile $OutputFile -SubKey "SOFTWARE\Microsoft\Internet Explorer\TypedURLs"
    }

    function Get-InternetSettings {
        param(
            [string]$OutputFile = "$InternetFolder\internet_settings.csv"
        )
        Export-PerUserRegistry -OutputFile $OutputFile -SubKey "SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings"
    }

    function Get-TrustedInternetDomains {
        param(
            [string]$OutputFile = "$InternetFolder\trusted_internet_domains.csv"
        )
        Export-PerUserRegistry -EnumerateSubKeys -OutputFile $OutputFile -SubKey "SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains"
    }

    function Get-BrowserAnalysis {
        param(
            [string]$OutputFile = "$InternetFolder\browser_analysis.txt"
        )

        try {
            $SqlitePath = Get-TriageBinary "SQLite3"
        }
        catch {
            Show-Message -Message "sqlite3.exe is unavailable. Skipping browser analysis => $( $_.Exception.Message )" -Level ERROR -AddToLog
            return
        }

        Show-Message -Message "Output will be $OutputFile..." -Level INFO -AddToLog -MessageColor Magenta

        $BrowserPaths = [ordered]@{
            "Chrome"  = "AppData\Local\Google\Chrome\User Data\Default\History"
            "Brave"   = "AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\History"
            "Edge"    = "AppData\Local\Microsoft\Edge\User Data\Default\History"
            "Firefox" = "AppData\Roaming\Mozilla\Firefox\Profiles\*\places.sqlite"
        }

        # Dates stay in UTC
        $Queries = [ordered]@{
            "Url_analysis"                 = "SELECT datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch') AS VisitTimeUTC, visit_count AS VisitCount, title AS Title, url AS Url FROM urls ORDER BY last_visit_time DESC"

            "keyword_search_term_analysis" = "SELECT url_id AS TermId, term AS SearchTerm FROM keyword_search_terms ORDER BY url_id DESC"

            "download_analysis"            = "SELECT datetime((start_time / 1000000) - 11644473600, 'unixepoch') AS DownloadStartUTC, datetime((end_time / 1000000) - 11644473600, 'unixepoch') AS DownloadEndUTC, round(total_bytes / 1048576.0, 3) AS SizeMB, mime_type AS MimeType, opened AS OpenedFromBrowser, current_path AS SavedPath, tab_url AS DownloadedFrom FROM downloads ORDER BY start_time DESC"
        }

        foreach ($UserDir in (Get-ChildItem -LiteralPath "$env:SystemDrive\Users" -Directory -Force)) {
            foreach ($BrowserName in $BrowserPaths.Keys) {
                $Source = Join-Path -Path $UserDir.FullName -ChildPath $BrowserPaths[$BrowserName]

                if (-not (Test-Path -LiteralPath $Source)) {
                    continue
                }

                $BrowserDir = Join-Path -Path $InternetFolder -ChildPath "Browser_Analysis\$BrowserName"
                $null = New-Item -ItemType Directory -Path $BrowserDir -Force

                # Copy the database, plus its -wal/-journal files, so recent
                # entries are not lost
                $Db = Join-Path -Path $BrowserDir -ChildPath "$( $UserDir.Name )-$BrowserName-History-File.sqlite"
                try {
                    Copy-Item -LiteralPath $Source -Destination $Db -ErrorAction Stop
                    foreach ($Suffix in "-wal", "-journal", "-shm") {
                        if (Test-Path -LiteralPath "$Source$Suffix") {
                            Copy-Item -LiteralPath "$Source$Suffix" -Destination "$Db$Suffix" -ErrorAction SilentlyContinue
                        }
                    }
                }
                catch {
                    Show-Message -Message "Could not copy $BrowserName history for $( $UserDir.Name ) => $( $_.Exception.Message )" -Level ERROR -AddToLog
                    continue
                }

                foreach ($Q in $Queries.GetEnumerator()) {
                    $OutFile = Join-Path -Path $BrowserDir -ChildPath "$( $UserDir.Name )-$BrowserName-$( $Q.Key ).csv"
                    # Database and query go in as separate arguments. 2>&1 captures sqlite3's error text.
                    $Out = & $SqlitePath -readonly -header -csv $Db $Q.Value 2>&1

                    if ($LASTEXITCODE -ne 0) {
                        Show-Message -Message "sqlite3 failed ($BrowserName / $( $UserDir.Name ) / $( $Q.Key )) => $( $Out -join ' ' )" -Level ERROR -AddToLog
                        continue
                    }

                    Show-Message -Message "sqlite3 -readonly -header -csv `"$Db`" <$( $Q.Key ) query>" -Level INFO -AddToLog
                    if ($Out) {
                        $Out | Set-Content -LiteralPath $OutFile -Encoding UTF8
                    }
                    else {
                        "No data was found for that query." | Set-Content -LiteralPath $OutFile -Encoding UTF8
                    }
                }
            }
        }
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $InternetWorkFlow = [ordered]@{
        { Get-TempInternetFiles } = (
            "Getting Temporary Internet Files (Last 5 Days)...",
            "temp_internet_files.csv"
        )
        { Get-StoredCookies } = (
            "Getting Stored Cookie Information...",
            "stored_cookies.csv"
        )
        { Get-TypedUrls } = (
            "Getting Typed URL Data...",
            "typed_urls.csv"
        )
        { Get-InternetSettings } = (
            "Getting Internet Setting Registry Keys...",
            "internet_settings.csv"
        )
        { Get-TrustedInternetDomains } = (
            "Getting Trusted Internet Domain Registry Keys...",
            "trusted_internet_domains.csv"
        )
        { Get-BrowserAnalysis } = (
            "Analyzing All Browser Data...",
            "browser_analysis.txt"
        )
    }

    foreach ($Task in $InternetWorkFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $Task.Key -FunctionMessage $Task.Value[0] -OutputFile $Task.Value[1]
    }
}
