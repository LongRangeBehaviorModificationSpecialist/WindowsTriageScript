function Get-TriageInternetData {
    [CmdletBinding()]
    param(
        [string]$internet_folder
    )


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$action,
            [string]$function_msg,
            [string]$output_file
        )
        try {
            Show-MessageAndWriteLogEntry -Msg $function_msg -Level INFO
            & $action
            Show-MessageAndWriteLogEntry -File $output_file -Level SUCCESS
        }
        catch {
            $error_msg = "Execution failed during `"$($MyInvocation.MyCommand.Name)`". Error: $($_.Exception.Message)"
            Show-MessageAndWriteLogEntry -Msg $error_msg -Level ERROR
        }
    }


    function Get-TempInternetFiles {
        param(
            [string]$output_file = "$internet_folder\temp_internet_files.txt"
        )
        $command =  { Get-ChildItem -Recurse -Force "$env:LOCALAPPDATA\Microsoft\Windows\Temporary Internet Files" |
                        Select-Object Name, LastWriteTime, CreationTime, Directory |
                        Where-Object { $_.LastWriteTime -gt ((Get-Date).AddDays(-5)) } |
                        Sort-Object CreationTime -Desc
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-StoredCookies {
        param(
            [string]$output_file = "$internet_folder\stored_cookies.txt"
        )
        $command =  { Get-ChildItem -Recurse -Force "$env:APPDATA\Microsoft\Windows\cookies" |
                        Select-Object Name |
                        ForEach-Object { $n = $_.Name; Get-Content "$env:APPDATA\Microsoft\Windows\cookies\$n" |
                            Select-String "/" }
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-TypedUrls {
        param(
            [string]$output_file = "$internet_folder\typed_urls.txt"
        )
        $command =  { Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Internet Explorer\TypedURLs" |
                        Select-Object * -ExcludeProperty PS*
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-InternetSettings {
        param(
            [string]$output_file = "$internet_folder\internet_settings.txt"
        )
        $command =  { Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" |
                        Select-Object * -ExcludeProperty PS*
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-TrustedInternetDomains {
        param(
            [string]$output_file = "$internet_folder\trusted_internet_domains.txt"
        )
        $command =  { Get-ChildItem "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains" |
                        Select-Object PSChildName
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-ChromeHistory {
        param(
            [string]$output_file = "$internet_folder\chrome_visit_history.txt"
        )
        $sqlite_path = $binaries["SQLite3"]
        $chrome_history_path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"

        if ((Test-Path $chrome_history_path) -and (Test-Path $sqlite_path)) {
            # Copy the history file to a temporary location so it works even if Chrome is open
            $temp_history_path = Join-Path -Path $temp_folder -ChildPath "Chrome_History_Copy"
            $null              = New-Item -ItemType Directory -Name $temp_history_path
            Copy-Item -Path $chrome_history_path -Destination $temp_history_path -Force
            Add-Content -Path $output_file -Value "`nGoogle Chrome History:`n"

            $query = "SELECT ROW_NUMBER() OVER() AS 'row_number', datetime(last_visit_time/1000000 - 11644473600, 'unixepoch') AS LastVisit, url, title FROM urls ORDER BY last_visit_time DESC"

            $data    = & $sqlite_path $temp_history_path $query
            $command = "$sqlite_path `"$temp_history_path`" `"$query`""

            Write-OutputToFile -Command $command -Data $data -OutputFile $output_file -Append
        }
        else {
            Add-Content -Path $output_file -Value "Chrome History file or sqlite3.exe not found." -Encoding UTF8
        }
    }


    function Get-ChromeDownloads {
        param(
            [string]$output_file = "$internet_folder\chrome_download_history.txt"
        )
        $sqlite_path = $binaries["SQLite3"]
        $chrome_history_path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"

        if ((Test-Path $chrome_history_path) -and (Test-Path $sqlite_path)) {
            # Copy the history file to a temporary location so it works even if Chrome is open
            $temp_history_path = Join-Path -Path $temp_folder -ChildPath "Chrome_History_Copy"
            $null              = New-Item -ItemType Directory -Name $temp_history_path
            Copy-Item -Path $chrome_history_path -Destination $temp_history_path -Force
            Add-Content -Path $output_file -Value "`nChrome Download History:`n"

            $query = "SELECT ROW_NUMBER() OVER() AS 'row_number', id, current_path, datetime(start_time/1000000 - 11644473600, 'unixepoch') AS 'StartTime', tab_url, printf('%,d', received_bytes) AS 'ReceivedBytes', printf('%,d', total_bytes) AS 'TotalBytes' FROM downloads ORDER BY start_time DESC"

            $data    = & $sqlite_path $temp_history_path $query
            $command = "$sqlite_path `"$temp_history_path`" `"$query`""

            Write-OutputToFile -Command $command -Data $data -OutputFile $output_file -Append
        }
        else {
            Add-Content -Path $output_file -Value "Chrome History file or sqlite3.exe not found." -Encoding UTF8
        }
    }


    function Get-BrowserAnalysis {
        param(
            [string]$output_file = $null
        )
        $output_file = Join-Path -Path $internet_folder -ChildPath "browser_analysis.txt"
        $sqlite_path = $binaries["SQLite3"]
        $names = Get-ChildItem -Path "C:\Users"

        foreach ($name in $names) {
            $full_user_path = Join-Path -Path C:\Users -ChildPath $name
            # List of browser paths
            $browser_paths = @{
                "Chrome" = "\AppData\Local\Google\Chrome\User Data\Default\History"
                "Brave"  = "AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\History"
                "Edge"   = "AppData\Local\Microsoft\Edge\User Data\Default\History"
                #"Opera" = "AppData\Roaming\Opera Software\Opera Stable\Default\History"
                #"Firefox" = "AppData\Roaming\Mozilla\Firefox\Profiles\*\places.sqlite"
            }

            # Make single search for each browser path
            foreach ($browser_name in $browser_paths.Keys) {
                # Full path to chech each user for each browser path
                $user_with_browser_path = Join-Path -Path $full_user_path -ChildPath $browser_paths[$browser_name]

                # If the user have the browser path.
                if (Test-Path $user_with_browser_path) {
                    $analysis_parent_dir  = Join-path -Path $internet_folder -ChildPath "Browser_Analysis"
                    $null                 = New-Item -ItemType Directory -Force -Path $analysis_parent_dir

                    $analysis_browser_dir = Join-Path -Path $analysis_parent_dir -ChildPath $browser_name
                    $null                 = New-Item -ItemType Directory -Force -Path "$analysis_browser_dir"

                    Copy-Item -Path $user_with_browser_path -Destination "$analysis_browser_dir\$name-$browser_name-History-File.sqlite"

                    $url_output_file      = Join-Path -Path $analysis_browser_dir -ChildPath "$name-$browser_name-Url_analysis.txt"
                    $keyword_output_file  = Join-Path -Path $analysis_browser_dir -ChildPath "$name-$browser_name-keyword_search_term_analysis.txt"
                    $download_output_file = Join-Path -Path $analysis_browser_dir -ChildPath "$name-$browser_name-download-analysis.txt"
                    $db                   = Join-Path -Path $analysis_browser_dir -ChildPath "$name-$browser_name-History-File.sqlite"

                    $url_query   = "SELECT datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch') AS 'Visit Time UTC Form', substr(datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch', '+3 hours'), 12, 8) AS 'GMT+3 IL', substr(datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch', '+2 hours'), 12, 8) AS 'GMT+2 IL', visit_count AS 'Count', SUBSTR(title, 1, 90) AS 'URL Title', url AS 'Full URL' FROM urls ORDER BY last_visit_time DESC"
                    $url_data    = & $sqlite_path $db $url_query
                    $url_command = "$sqlite_path `"$db`" `"$url_query`""
                    Write-OutputToFile -Command $url_command -Data $url_data -OutputFile $url_output_file

                    $keyword_query   = "SELECT url_id AS 'Term ID', term AS 'Browser Keyword Search Term' FROM keyword_search_terms ORDER BY url_id DESC"
                    $keyword_data    = & $sqlite_path $db $keyword_query
                    $keyword_command = "$sqlite_path `"$db`" `"$keyword_query`""
                    Write-OutputToFile -Command $keyword_command -Data $keyword_data -OutputFile $keyword_output_file

                    $download_query = "SELECT datetime((start_time / 1000000) - 11644473600, 'unixepoch') AS 'Download Start Time', strftime('%H:%M:S', (end_time / 1000000) - 11644473600, 'unixepoch') AS 'End Time', (ROUND(total_bytes / 1048576.0, 3) || ' MB') AS 'File Size', SUBSTR(mime_type, 1, 30) AS 'File Type', CASE WHEN opened = 1 THEN 'Yes' WHEN opened = 0 THEN 'No' ELSE opened END AS 'Opened From Browser?', current_path AS 'Path Of The Downloaded File', tab_url AS 'File Was Downloaded From This Link' FROM downloads ORDER BY start_time DESC"
                    $download_data    = & $sqlite_path $db $keyword_query
                    $download_command = "$sqlite_path `"$db`" `"$download_query`""
                    Write-OutputToFile -Command $download_command -Data $download_data -OutputFile $download_output_file
                }
            }
        }
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $internet_work_flow = [ordered]@{
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

    foreach ($task in $internet_work_flow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
