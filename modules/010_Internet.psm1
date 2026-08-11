function Get-TriageInternetData {
    [CmdletBinding()]
    param(
        [string]$InternetFolder
    )


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$Action,
            [string]$FunctionMsg,
            [string]$OutputFile
        )
        try {
            Show-MessageAndWriteLogEntry -Msg $FunctionMsg -Level INFO
            & $Action
            Show-MessageAndWriteLogEntry -File $OutputFile -Level SUCCESS
        }
        catch {
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error: $( $_.Exception.Message )"
            Show-MessageAndWriteLogEntry -Msg $ErrorMsg -Level ERROR
        }
    }


    function Get-TempInternetFiles {
        param(
            [string]$OutputFile = "$InternetFolder\temp_internet_files.txt"
        )
        $Command =  { Get-ChildItem -Recurse -Force "$env:LOCALAPPDATA\Microsoft\Windows\Temporary Internet Files" |
                        Select-Object Name, LastWriteTime, CreationTime, Directory |
                        Where-Object { $_.LastWriteTime -gt ((Get-Date).AddDays(-5)) } |
                        Sort-Object CreationTime -Desc
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-StoredCookies {
        param(
            [string]$OutputFile = "$InternetFolder\stored_cookies.txt"
        )
        $Command =  { Get-ChildItem -Recurse -Force "$env:APPDATA\Microsoft\Windows\cookies" |
                        Select-Object Name |
                        ForEach-Object { $N = $_.Name; Get-Content "$env:APPDATA\Microsoft\Windows\cookies\$N" |
                            Select-String "/" }
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-TypedUrls {
        param(
            [string]$OutputFile = "$InternetFolder\typed_urls.txt"
        )
        $Command =  { Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Internet Explorer\TypedURLs" |
                        Select-Object * -ExcludeProperty PS*
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-InternetSettings {
        param(
            [string]$OutputFile = "$InternetFolder\internet_settings.txt"
        )
        $Command =  { Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" |
                        Select-Object * -ExcludeProperty PS*
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-TrustedInternetDomains {
        param(
            [string]$OutputFile = "$InternetFolder\trusted_internet_domains.txt"
        )
        $Command =  { Get-ChildItem "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains" |
                        Select-Object PSChildName
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-ChromeHistory {
        param(
            [string]$OutputFile = "$InternetFolder\chrome_visit_history.txt"
        )
        $SqlitePath = $Binaries["SQLite3"]
        $ChromeHistoryPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"

        if ((Test-Path $ChromeHistoryPath) -and (Test-Path $SqlitePath)) {
            # Copy the history file to a temporary location so it works even if Chrome is open
            $TempHistoryPath = Join-Path -Path $TempFolder -ChildPath "Chrome_History_Copy"
            $null            = New-Item -ItemType Directory -Name $TempHistoryPath
            Copy-Item -Path $ChromeHistoryPath -Destination $TempHistoryPath -Force
            Add-Content -Path $OutputFile -Value "`nGoogle Chrome History:`n"

            $Query = "SELECT ROW_NUMBER() OVER() AS 'row_number', datetime(last_visit_time/1000000 - 11644473600, 'unixepoch') AS LastVisit, url, title FROM urls ORDER BY last_visit_time DESC"

            $Data    = & $SqlitePath $TempHistoryPath $Query
            $Command = "$SqlitePath `"$TempHistoryPath`" `"$Query`""

            Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile -Append
        }
        else {
            Add-Content -Path $OutputFile -Value "Chrome History file or sqlite3.exe not found." -Encoding UTF8
        }
    }


    function Get-ChromeDownloads {
        param(
            [string]$OutputFile = "$InternetFolder\chrome_download_history.txt"
        )
        $SqlitePath = $Binaries["SQLite3"]
        $ChromeHistoryPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"

        if ((Test-Path $ChromeHistoryPath) -and (Test-Path $SqlitePath)) {
            # Copy the history file to a temporary location so it works even if Chrome is open
            $TempHistoryPath = Join-Path -Path $TempFolder -ChildPath "Chrome_History_Copy"
            $null              = New-Item -ItemType Directory -Name $TempHistoryPath
            Copy-Item -Path $ChromeHistoryPath -Destination $TempHistoryPath -Force
            Add-Content -Path $OutputFile -Value "`nChrome Download History:`n"

            $Query = "SELECT ROW_NUMBER() OVER() AS 'row_number', id, current_path, datetime(start_time/1000000 - 11644473600, 'unixepoch') AS 'StartTime', tab_url, printf('%,d', received_bytes) AS 'ReceivedBytes', printf('%,d', total_bytes) AS 'TotalBytes' FROM downloads ORDER BY start_time DESC"

            $Data    = & $SqlitePath $TempHistoryPath $Query
            $Command = "$SqlitePath `"$TempHistoryPath`" `"$Query`""

            Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile -Append
        }
        else {
            Add-Content -Path $OutputFile -Value "Chrome History file or sqlite3.exe not found." -Encoding UTF8
        }
    }


    function Get-BrowserAnalysis {
        param(
            [string]$OutputFile = $null
        )
        $OutputFile = Join-Path -Path $InternetFolder -ChildPath "browser_analysis.txt"
        $SqlitePath = $Binaries["SQLite3"]
        $Names = Get-ChildItem -Path "C:\Users"

        foreach ($Name in $Names) {
            $FullUserPath = Join-Path -Path C:\Users -ChildPath $Name
            # List of browser paths
            $BrowserPaths = @{
                "Chrome" = "\AppData\Local\Google\Chrome\User Data\Default\History"
                "Brave"  = "AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\History"
                "Edge"   = "AppData\Local\Microsoft\Edge\User Data\Default\History"
                #"Opera" = "AppData\Roaming\Opera Software\Opera Stable\Default\History"
                #"Firefox" = "AppData\Roaming\Mozilla\Firefox\Profiles\*\places.sqlite"
            }

            # Make single search for each browser path
            foreach ($BrowserName in $BrowserPaths.Keys) {
                # Full path to chech each user for each browser path
                $UserWithBrowserPath = Join-Path -Path $FullUserPath -ChildPath $BrowserPaths[$BrowserName]

                # If the user have the browser path.
                if (Test-Path $UserWithBrowserPath) {
                    $AnalysisParentDir  = Join-path -Path $InternetFolder -ChildPath "Browser_Analysis"
                    $null               = New-Item -ItemType Directory -Force -Path $AnalysisParentDir

                    $AnalysisBrowserDir = Join-Path -Path $AnalysisParentDir -ChildPath $BrowserName
                    $null               = New-Item -ItemType Directory -Force -Path "$AnalysisBrowserDir"

                    Copy-Item -Path $UserWithBrowserPath -Destination "$AnalysisBrowserDir\$Name-$BrowserName-History-File.sqlite"

                    $UrlOutputFile      = Join-Path -Path $AnalysisBrowserDir -ChildPath "$Name-$BrowserName-Url_analysis.txt"
                    $KeywordOutputFile  = Join-Path -Path $AnalysisBrowserDir -ChildPath "$Name-$BrowserName-keyword_search_term_analysis.txt"
                    $DownloadOutputFile = Join-Path -Path $AnalysisBrowserDir -ChildPath "$Name-$BrowserName-download-analysis.txt"
                    $Db                 = Join-Path -Path $AnalysisBrowserDir -ChildPath "$Name-$BrowserName-History-File.sqlite"

                    $UrlQuery   = "SELECT datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch') AS 'Visit Time UTC Form', substr(datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch', '+3 hours'), 12, 8) AS 'GMT+3 IL', substr(datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch', '+2 hours'), 12, 8) AS 'GMT+2 IL', visit_count AS 'Count', SUBSTR(title, 1, 90) AS 'URL Title', url AS 'Full URL' FROM urls ORDER BY last_visit_time DESC"
                    $UrlData    = & $SqlitePath $Db $UrlQuery
                    $UrlCommand = "$SqlitePath `"$Db`" `"$UrlQuery`""
                    Write-OutputToFile -Command $UrlCommand -Data $UrlData -OutputFile $UrlOutputFile

                    $KeywordQuery   = "SELECT url_id AS 'Term ID', term AS 'Browser Keyword Search Term' FROM keyword_search_terms ORDER BY url_id DESC"
                    $KeywordData    = & $SqlitePath $Db $KeywordQuery
                    $KeywordCommand = "$SqlitePath `"$Db`" `"$KeywordQuery`""
                    Write-OutputToFile -Command $KeywordCommand -Data $KeywordData -OutputFile $KeywordOutputFile

                    $DownloadQuery = "SELECT datetime((start_time / 1000000) - 11644473600, 'unixepoch') AS 'Download Start Time', strftime('%H:%M:S', (end_time / 1000000) - 11644473600, 'unixepoch') AS 'End Time', (ROUND(total_bytes / 1048576.0, 3) || ' MB') AS 'File Size', SUBSTR(mime_type, 1, 30) AS 'File Type', CASE WHEN opened = 1 THEN 'Yes' WHEN opened = 0 THEN 'No' ELSE opened END AS 'Opened From Browser?', current_path AS 'Path Of The Downloaded File', tab_url AS 'File Was Downloaded From This Link' FROM downloads ORDER BY start_time DESC"
                    $DownloadData    = & $SqlitePath $Db $KeywordQuery
                    $DownloadCommand = "$SqlitePath `"$Db`" `"$DownloadQuery`""
                    Write-OutputToFile -Command $DownloadCommand -Data $DownloadData -OutputFile $DownloadOutputFile
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
            "temp_internet_files.txt"
        )
        { Get-StoredCookies } = (
            "Getting Stored Cookie Information...",
            "stored_cookies.txt"
        )
        { Get-TypedUrls } = (
            "Getting Typed URL Data...",
            "typed_urls.txt"
        )
        { Get-InternetSettings } = (
            "Getting Internet Setting Registry Keys...",
            "internet_settings.txt"
        )
        { Get-TrustedInternetDomains } = (
            "Getting Trusted Internet Domain Registry Keys...",
            "trusted_internet_domains.txt"
        )
        { Get-ChromeHistory } = (
            "Getting Google Chrome URL History (if applicable)...",
            "chrome_visit_history.txt"
        )
        { Get-ChromeDownloads } = (
            "Getting Google Chrome Download History (if applicable)...",
            "chrome_download_history.txt"
        )
        { Get-BrowserAnalysis } = (
            "Analyzing All Browser Data...",
            "browser_analysis.txt"
        )
    }

    foreach ($Task in $InternetWorkFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $Task.key -functionMsg $Task.value[0] -OutputFile $Task.value[1]
    }
}
