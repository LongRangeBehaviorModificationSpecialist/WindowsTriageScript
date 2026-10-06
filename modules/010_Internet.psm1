function Get-TriageInternetData {
    [CmdletBinding()]
    param(
        [string]$InternetFolder
    )

    $TempFolder = Join-Path -Path $InternetFolder -ChildPath "temp"
    $null       = New-Item -ItemType Directory -Path $TempFolder

    function Get-TempInternetFiles {
        param(
            [string]$OutputFile = "$InternetFolder\001_temp_internet_files.csv"
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
            [string]$OutputFile = "$InternetFolder\002_stored_cookies.csv"
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
            [string]$OutputFile = "$InternetFolder\003_typed_urls.csv"
        )
        Export-PerUserRegistry -OutputFile $OutputFile -SubKey "SOFTWARE\Microsoft\Internet Explorer\TypedURLs"
    }

    function Get-InternetSettings {
        param(
            [string]$OutputFile = "$InternetFolder\004_internet_settings.csv"
        )
        Export-PerUserRegistry -OutputFile $OutputFile -SubKey "SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings"
    }

    function Get-TrustedInternetDomains {
        param(
            [string]$OutputFile = "$InternetFolder\005_trusted_internet_domains.csv"
        )
        Export-PerUserRegistry -EnumerateSubKeys -OutputFile $OutputFile -SubKey "SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains"
    }

    function Get-BrowserAnalysis {
        param(
            [string]$SummaryFile = (Join-Path -Path $InternetFolder -ChildPath "006_browser_analysis_summary.csv")
            )

        function Copy-SharedFile {
            # Normal copy first. If a running browser has the file locked,
            # retry with a stream opened for shared read access.
            param(
                [string]$Source,
                [string]$Destination
            )
            try {
                Copy-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop
            }
            catch {
                $In  = $null
                $Out = $null
                try {
                    $Share = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
                    $In    = [System.IO.File]::Open($Source, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $Share)
                    $Out    = [System.IO.File]::Open($Destination, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
                    $In.CopyTo($Out)
                }
                catch {
                    if ($Out) {
                        $Out.Dispose()
                        $Out = $null
                    }
                    Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
                    throw
                }
                finally {
                    if ($In)  { $In.Dispose() }
                    if ($Out) { $Out.Dispose() }
                }
            }
        }

        # Trusted sqlite3 path (a string; do NOT call it with & here)
        try {
            $SqlitePath = [string](Get-TriageBinary "SQLite3")
        }
        catch {
            Show-Message -Message "sqlite3.exe is unavailable. Skipping browser analysis => $( $_.Exception.Message )" -Level ERROR -AddToLog
            return
        }

        # Each browser's root folder holds one sub-folder per profile
        # (Chromium: Default, Profile 1, ... /
        # Firefox: <random>.default-release, ...)
        $Browsers = [ordered]@{
            "Chrome"  = @{
                Type = "Chromium"
                Root = "AppData\Local\Google\Chrome\User Data"
            }
            "Edge"    = @{
                Type = "Chromium"
                Root = "AppData\Local\Microsoft\Edge\User Data"
            }
            "Brave"   = @{
                Type = "Chromium"
                Root = "AppData\Local\BraveSoftware\Brave-Browser\User Data"
            }
            "Vivaldi" = @{
                Type = "Chromium"
                Root = "AppData\Local\Vivaldi\User Data"
            }
            "Firefox" = @{
                Type = "Firefox"
                Root = "AppData\Roaming\Mozilla\Firefox\Profiles"
            }
        }

        # All times are UTC
        $Queries = @{
            "Chromium" = [ordered]@{
                "Urls"        = "SELECT datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch') AS VisitTimeUTC, visit_count AS VisitCount, typed_count AS TypedCount, title AS Title, url AS Url FROM urls ORDER BY last_visit_time DESC"

                "Visits"      = "SELECT datetime((v.visit_time / 1000000) - 11644473600, 'unixepoch') AS VisitTimeUTC, u.url AS Url, u.title AS Title, v.transition AS Transition FROM visits v JOIN urls u ON u.id = v.url ORDER BY v.visit_time DESC"

                "SearchTerms" = "SELECT datetime((u.last_visit_time / 1000000) - 11644473600, 'unixepoch') AS LastVisitUTC, k.term AS SearchTerm, u.url AS Url FROM keyword_search_terms k JOIN urls u ON u.id = k.url_id ORDER BY u.last_visit_time DESC"

                "Downloads"   = "SELECT datetime((start_time / 1000000) - 11644473600, 'unixepoch') AS DownloadStartUTC, datetime((end_time / 1000000) - 11644473600, 'unixepoch') AS DownloadEndUTC, round(total_bytes / 1048576.0, 3) AS SizeMB, mime_type AS MimeType, opened AS OpenedFromBrowser, current_path AS SavedPath, tab_url AS DownloadedFrom FROM downloads ORDER BY start_time DESC"
            }
            "Firefox" = [ordered]@{
                "Urls"      = "SELECT datetime(last_visit_date / 1000000, 'unixepoch') AS LastVisitUTC, visit_count AS VisitCount, title AS Title, url AS Url FROM moz_places WHERE last_visit_date IS NOT NULL ORDER BY last_visit_date DESC"

                "Visits"    = "SELECT datetime(v.visit_date / 1000000, 'unixepoch') AS VisitTimeUTC, p.url AS Url, p.title AS Title, v.visit_type AS VisitType FROM moz_historyvisits v JOIN moz_places p ON p.id = v.place_id ORDER BY v.visit_date DESC"

                "Downloads" = "SELECT datetime(a.dateAdded / 1000000, 'unixepoch') AS AddedUTC, n.name AS Attribute, a.content AS Content, p.url AS Url FROM moz_annos a JOIN moz_anno_attributes n ON n.id = a.anno_attribute_id JOIN moz_places p ON p.id = a.place_id WHERE n.name LIKE 'downloads/%' ORDER BY a.dateAdded DESC"
            }
        }

        # Profiles found by the hive-mounting step (covers profiles outside
        # C:\Users). Fall back to C:\Users if that list is empty.
        $ProfilePaths = @($global:TriageUserHives |
            Where-Object { $_.ProfilePath -and (Test-Path -LiteralPath $_.ProfilePath -PathType Container) } |
            Sort-Object -Property ProfilePath -Unique |
            ForEach-Object { $_.ProfilePath })

        if ($ProfilePaths.Count -eq 0) {
            Show-Message -Message "No mounted user profiles were found. Falling back to [ $env:SystemDrive\Users ]." -Level WARNING -AddToLog

            $ProfilePaths = @(Get-ChildItem -LiteralPath "$env:SystemDrive\Users" -Directory -Force -ErrorAction SilentlyContinue |
                ForEach-Object { $_.FullName })
        }

        $Summary   = [System.Collections.Generic.List[object]]::new()
        $DbFound   = 0
        $Failures  = 0

        # `sqlite3` writes UTF-8, but PowerShell decodes native output with the
        # console code page. Switch it for the duration of the queries so
        # non-ASCII titles are not mangled.
        $OldEncoding = $null
        try {
            $OldEncoding = [Console]::OutputEncoding
            [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
        }
        catch {
            $OldEncoding = $null
        }

        try {
            foreach ($ProfilePath in $ProfilePaths) {
                Show-Message -Message "Profile found => [ $ProfilePath ]" -MessageColor Magenta
                $UserLeaf = Split-Path -Path $ProfilePath -Leaf

                # foreach ($Browser in (Get-TriageConfig -Key "Browsers")) {
                foreach ($BrowserName in $Browsers.Keys) {
                    Show-Message -Message "Examining $BrowserName data in [ $ProfilePath ]" -MessageColor Magenta
                    $Browser = $Browsers[$BrowserName]
                    # $Browser = $Browser.Name
                    $Root    = Join-Path -Path $ProfilePath -ChildPath $Browser.Root
                    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
                        continue
                    }

                    $DbName = if ($Browser.Type -eq "Chromium") {
                        "History"
                    }
                    else {
                        "places.sqlite"
                    }

                    foreach ($ProfileDir in (Get-ChildItem -LiteralPath $Root -Directory -Force -ErrorAction SilentlyContinue)) {
                        $Source = Join-Path -Path $ProfileDir.FullName -ChildPath $DbName
                        if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
                            continue
                        }

                        $DbFound++
                        $Tag        = ("{0}-{1}-{2}" -f $UserLeaf, $BrowserName, $ProfileDir.Name) -replace "[^\w\.\-]", "_"
                        $BrowserDir = Join-Path -Path $InternetFolder -ChildPath "Browser_Analysis\$BrowserName"
                        $null       = New-Item -ItemType Directory -Path $BrowserDir -Force
                        $Db         = Join-Path -Path $BrowserDir -ChildPath "$Tag-$DbName.sqlite"

                        # Copy the database plus its -wal/-journal files so
                        # recent entries are not lost. (-shm is not copied;
                        # SQLite rebuilds it from the WAL, and a stale copy can
                        # confuse it.)
                        try {
                            Copy-SharedFile -Source $Source -Destination $Db
                            foreach ($Suffix in "-wal", "-journal") {
                                if (Test-Path -LiteralPath "$Source$Suffix") {
                                    try {
                                        Copy-SharedFile -Source "$Source$Suffix" -Destination "$Db$Suffix"
                                    }
                                    catch {
                                        Show-Message -Message "Could not copy $( Split-Path "$Source$Suffix" -Leaf ) for $Tag => $( $_.Exception.Message )" -Level WARNING -AddToLog
                                    }
                                }
                            }
                        }
                        catch {
                            $Failures++
                            Show-Message -Message "Could not copy [ $BrowserName ] database for [ $Tag ] => $( $_.Exception.Message )" -Level ERROR -AddToLog
                            $Summary.Add([pscustomobject]@{
                                User       = $UserLeaf
                                Browser    = $BrowserName
                                Profile    = $ProfileDir.Name
                                SourceFile = $Source
                                CopiedTo   = ""
                                Query      = ""
                                Rows       = 0
                                Status     = "CopyFailed"
                                Detail     = $_.Exception.Message
                            })
                            continue
                        }

                        Show-Message -Message "Browser database copied [ $Tag ]" -Level INFO -AddToLog -MessageColor Green

                        foreach ($Q in $Queries[$Browser.Type].GetEnumerator()) {
                            $OutFile = Join-Path -Path $BrowserDir -ChildPath "$Tag-$( $Q.Key ).csv"
                            $Rows    = 0
                            $Status  = "OK"
                            $Detail  = ""

                            try {
                                $Raw  = & $SqlitePath -batch -readonly -header -csv $Db $Q.Value 2>&1
                                $Code = $LASTEXITCODE

                                $ErrText = @($Raw | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.ToString() })
                                $Lines   = @($Raw | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })

                                if ($Code -ne 0) {
                                    $Detail = (($ErrText + $Lines) -join " ").Trim()
                                    if ($Detail -match "no such table|no such column") {
                                        $Status = "NotPresent"
                                        Show-Message -Message "($Tag) '$( $Q.Key )' is not available in this database version." -Level INFO -AddToLog
                                    }
                                    else {
                                        $Status = "Failed"
                                        $Failures++
                                        Show-Message -Message "sqlite3 failed ($Tag / $( $Q.Key )) => $Detail" -Level ERROR -AddToLog
                                    }
                                }
                                elseif ($Lines.Count -gt 0) {
                                    $Lines | Set-Content -LiteralPath $OutFile -Encoding UTF8

                                    # Exact row count from SQLite itself
                                    $CountOut = & $SqlitePath -batch -readonly $Db "SELECT COUNT(*) FROM ($( $Q.Value ))" 2>$null
                                    $Parsed   = 0
                                    if ([int]::TryParse(([string]($CountOut | Select-Object -First 1)).Trim(), [ref]$Parsed)) { $Rows = $Parsed }
                                    else { $Rows = -1 }       # written, but the count was unavailable
                                }
                                else {
                                    $Status = "NoData"
                                    "No data was found for that query." | Set-Content -LiteralPath $OutFile -Encoding UTF8
                                }
                            }
                            catch {
                                $Status = "Failed"
                                $Failures++
                                $Detail = $_.Exception.Message
                                Show-Message -Message "Query '$( $Q.Key )' failed for $Tag => $Detail" -Level ERROR -AddToLog
                            }

                            $Summary.Add([pscustomobject]@{
                                User = $UserLeaf; Browser = $BrowserName; Profile = $ProfileDir.Name
                                SourceFile = $Source
                                CopiedTo   = $Db.Substring($InternetFolder.Length).TrimStart("\")
                                Query = $Q.Key; Rows = $Rows; Status = $Status; Detail = $Detail
                            })
                        }
                    }
                }
            }
        }
        finally {
            if ($OldEncoding) {
                try {
                    [Console]::OutputEncoding = $OldEncoding
                }
                catch { }
            }
        }

        Write-OutputToCsv -Data $Summary -OutputFile $SummaryFile
        Show-Message -Message "Browser analysis => $DbFound database(s) found, $Failures failure(s)." -Level INFO -AddToLog
        # Show-Message -Message "Summary => [ $( Split-Path $SummaryFile -Leaf ) ]" -Level INFO -AddToLog
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $Tasks = @(
        @{
            Action  = { Get-TempInternetFiles }
            Message = "Getting Temporary Internet Files (Last 5 Days)..."
            Files   = "001_temp_internet_files.csv"
        }
        @{
            Action  = { Get-StoredCookies }
            Message = "Getting Stored Cookie Information..."
            Files   = "002_stored_cookies.csv"
        }
        @{
            Action  = { Get-TypedUrls }
            Message = "Getting Typed URL Data..."
            Files   = "003_typed_urls.csv"
        }
        @{
            Action  = { Get-InternetSettings }
            Message = "Getting Internet Setting Registry Keys..."
            Files   = "004_internet_settings.csv"
        }
        @{
            Action  = { Get-TrustedInternetDomains }
            Message = "Getting Trusted Internet Domain Registry Keys..."
            Files   = "005_trusted_internet_domains.csv"
        }
        @{
            Action  = { Get-BrowserAnalysis }
            Message = "Analyzing All Browser Data..."
            Files   = "006_browser_analysis_summary.csv"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $InternetFolder
}
