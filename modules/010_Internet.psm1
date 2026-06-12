function Get-TriageInternetData {
    [CmdletBinding()]
    param(
        [string]$internetFolder
    )


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$action,
            [string]$functionMsg,
            [string]$outputFile
        )
        try {
            Show-MessageAndWriteLogEntry -Message $functionMsg -Level INFO
            & $action
            Show-MessageAndWriteLogEntry -File $outputFile -Level SUCCESS
        }
        catch {
            $errorMessage = "Execution failed during '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
            Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
        }
    }


    function Get-TempInternetFiles {
        param(
            [string]$outputFile = "$internetFolder\temp_internet_files.txt"
        )
        $command = { Get-ChildItem -Recurse -Force "$env:LOCALAPPDATA\Microsoft\Windows\Temporary Internet Files" | Select-Object Name, LastWriteTime, CreationTime, Directory | Where-Object { $_.LastWriteTime -gt ((Get-Date).AddDays(-5)) } | Sort-Object CreationTime -Desc }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-StoredCookies {
        param(
            [string]$outputFile = "$internetFolder\stored_cookies.txt"
        )
        $command = { Get-ChildItem -Recurse -Force "$env:APPDATA\Microsoft\Windows\cookies" | Select-Object Name | ForEach-Object { $n = $_.Name; Get-Content "$env:APPDATA\Microsoft\Windows\cookies\$n" | Select-String "/" } }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-TypedUrls {
        param(
            [string]$outputFile = "$internetFolder\typed_urls.txt"
        )
        $command = { Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Internet Explorer\TypedURLs" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-InternetSettings {
        param(
            [string]$outputFile = "$internetFolder\internet_settings.txt"
        )
        $command = { Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-TrustedInternetDomains {
        param(
            [string]$outputFile = "$internetFolder\trusted_internet_domains.txt"
        )
        $command = { Get-ChildItem "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains" | Select-Object PSChildName }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-ChromeHistory {
        param(
            [string]$outputFile = "$internetFolder\chrome_visit_history.txt"
        )
        $sqlitePath = $binaries["SQLite3"]
        $chromeHistoryPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"
        if ((Test-Path $chromeHistoryPath) -and (Test-Path $sqlitePath)) {
            # Copy the history file to a temporary location so it works even if Chrome is open
            $TempHistoryPath = Join-Path -Path $TempFolder -ChildPath "ChromeHistoryCopy"
            Copy-Item -Path $chromeHistoryPath -Destination $TempHistoryPath -Force
            Add-Content -Path $outputFile -Value "`nGoogle Chrome History:`n"
            $Query = "SELECT ROW_NUMBER() OVER() AS 'row_number', datetime(last_visit_time/1000000 - 11644473600, 'unixepoch') AS LastVisit, url, title FROM urls ORDER BY last_visit_time DESC"
            $data = & $sqlitePath $TempHistoryPath $Query
            $command = "$sqlitePath `"$TempHistoryPath`" `"$Query`""
            Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile -Append
        }
        else {
            Add-Content -Path $outputFile -Value "Chrome History file or sqlite3.exe not found."
        }
    }


    function Get-ChromeDownloads {
        param(
            [string]$outputFile = "$internetFolder\chrome_download_history.txt"
        )
        $sqlitePath = $binaries["SQLite3"]
        $chromeHistoryPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"
        if ((Test-Path $chromeHistoryPath) -and (Test-Path $sqlitePath)) {
            # Copy the history file to a temporary location so it works even if Chrome is open
            $TempHistoryPath = Join-Path -Path $TempFolder -ChildPath "ChromeHistoryCopy"
            Add-Content -Path $outputFile -Value "`nChrome Download History:`n"
            $Query = "SELECT ROW_NUMBER() OVER() AS 'row_number', id, current_path, datetime(start_time/1000000 - 11644473600, 'unixepoch') AS 'StartTime', tab_url, printf('%,d', received_bytes) AS 'ReceivedBytes', printf('%,d', total_bytes) AS 'TotalBytes' FROM downloads ORDER BY start_time DESC"
            $data = & $sqlitePath $TempHistoryPath $Query
            $command = "$sqlitePath `"$TempHistoryPath`" `"$Query`""
            Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile -Append
        }
        else {
            Add-Content -Path $outputFile -Value "Chrome History file or sqlite3.exe not found."
        }
    }


    function Get-BrowserAnalysis {
        param(
            [string]$outputFile = "$internetFolder\browser_analysis.txt"
        )
        $sqlitePath = $binaries["SQLite3"]
        $names = Get-ChildItem -Path "C:\Users"

        foreach ($name in $names) {
            $fullUserPath = Join-Path -Path C:\Users -ChildPath $name
            # List of browser paths
            $browserPaths = @{
                "Chrome" = "\AppData\Local\Google\Chrome\User Data\Default\History"
                "Brave"  = "AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\History"
                "Edge"   = "AppData\Local\Microsoft\Edge\User Data\Default\History"
                #"Opera" = "AppData\Roaming\Opera Software\Opera Stable\Default\History"
                #"Firefox" = "AppData\Roaming\Mozilla\Firefox\Profiles\*\places.sqlite"
            }

            # foreach loop to make single search for each browser path
            foreach ($browserName in $browserPaths.Keys) {
                # Full path to chech each user for each browser path
                $userWithBrowserPath = Join-Path -Path $fullUserPath -ChildPath $browserPaths[$browserName]

                # If the user have the browser path.
                if (Test-Path $userWithBrowserPath) {
                    $analysisParentDir  = "$internetFolder\Browser_Analysis"
                    $analysisBrowserDir = "$analysisParentDir\$browserName"
                    $null = New-Item -ItemType Directory -Force -Path $analysisParentDir
                    $null = New-Item -ItemType Directory -Force -Path "$analysisBrowserDir"
                    Copy-Item -Path $userWithBrowserPath -Destination "$analysisBrowserDir\$name-$browserName-History-File.sqlite"
                    $urlOutputFile      = "$analysisBrowserDir\$name-$browserName-Url_analysis.txt"
                    $keywordOutputFile  = "$analysisBrowserDir\$name-$browserName-keyword_search_term_analysis.txt"
                    $downloadOutputFile = "$analysisBrowserDir\$name-$browserName-download-analysis.txt"
                    $db                 = "$analysisBrowserDir\$name-$browserName-History-File.sqlite"

                    $urlQuery   = "SELECT datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch') AS 'Visit Time UTC Form', substr(datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch', '+3 hours'), 12, 8) AS 'GMT+3 IL', substr(datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch', '+2 hours'), 12, 8) AS 'GMT+2 IL', visit_count AS 'Count', SUBSTR(title, 1, 90) AS 'URL Title', url AS 'Full URL' FROM urls ORDER BY last_visit_time DESC"
                    $urlData    = & $sqlitePath $db $urlQuery
                    $urlCommand = "$sqlitePath '$db' '$urlQuery'"
                    Write-OutputToFile -Command $urlCommand -Data $urlData -OutputFile $urlOutputFile

                    $keywordQuery   = "SELECT url_id AS 'Term ID', term AS 'Browser Keyword Search Term' FROM keyword_search_terms ORDER BY url_id DESC"
                    $keywordData    = & $sqlitePath $db $keywordQuery
                    $keywordCommand = "$sqlitePath '$db' '$keywordQuery'"
                    Write-OutputToFile -Command $keywordCommand -Data $keywordData -OutputFile $keywordOutputFile

                    $downloadQuery = "SELECT datetime((start_time / 1000000) - 11644473600, 'unixepoch') AS 'Download Start Time', strftime('%H:%M:S', (end_time / 1000000) - 11644473600, 'unixepoch') AS 'End Time', (ROUND(total_bytes / 1048576.0, 3) || ' MB') AS 'File Size', SUBSTR(mime_type, 1, 30) AS 'File Type', CASE WHEN opened = 1 THEN 'Yes' WHEN opened = 0 THEN 'No' ELSE opened END AS 'Opened From Browser?', current_path AS 'Path Of The Downloaded File', tab_url AS 'File Was Downloaded From This Link' FROM downloads ORDER BY start_time DESC"
                    $downloadData    = & $sqlitePath $db $keywordQuery
                    $downloadCommand = "$sqlitePath '$db' '$downloadQuery'"
                    Write-OutputToFile -Command $downloadCommand -Data $downloadData -OutputFile $downloadOutputFile
                }
            }
        }
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $workFlow = [ordered]@{
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

    foreach ($task in $workFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
