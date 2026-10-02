function Get-TriageInternetData {
    [CmdletBinding()]
    param([string]$InternetFolder)

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
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error => $( $_.Exception.Message )"
            Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
        }
    }

    function Get-TempInternetFiles {
        param([string]$OutputFile = "$InternetFolder\temp_internet_files.csv")
        $Cutoff = (Get-Date).AddDays(-5)
        $Data = foreach ($U in $global:TriageUserHives) {
            $Dir = Join-Path $U.ProfilePath 'AppData\Local\Microsoft\Windows\INetCache'
            if (-not (Test-Path -LiteralPath $Dir)) { continue }
            Get-ChildItem -LiteralPath $Dir -Recurse -Force -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -gt $Cutoff } |
                Select-Object @{N='UserName';E={$U.UserName}}, FullName, CreationTimeUtc, LastWriteTimeUtc, Length
        }
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-StoredCookies {
        param([string]$OutputFile = "$InternetFolder\stored_cookies.csv")
        $Data = foreach ($U in $global:TriageUserHives) {
            $Dir = Join-Path $U.ProfilePath 'AppData\Local\Microsoft\Windows\INetCookies'
            if (-not (Test-Path -LiteralPath $Dir)) { continue }
            foreach ($File in Get-ChildItem -LiteralPath $Dir -Recurse -Force -File -ErrorAction SilentlyContinue) {
                Select-String -LiteralPath $File.FullName -Pattern '/' -ErrorAction SilentlyContinue | ForEach-Object {
                    [pscustomobject]@{ UserName = $U.UserName; File = $File.Name; Line = $_.Line }
                }
            }
        }
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-TypedUrls {
        param([string]$OutputFile = "$InternetFolder\typed_urls.csv")
        Export-PerUserRegistry -OutputFile $OutputFile -SubKey 'SOFTWARE\Microsoft\Internet Explorer\TypedURLs'
    }

    function Get-InternetSettings {
        param([string]$OutputFile = "$InternetFolder\internet_settings.csv")
        Export-PerUserRegistry -OutputFile $OutputFile -SubKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings'
    }

    function Get-TrustedInternetDomains {
        param([string]$OutputFile = "$InternetFolder\trusted_internet_domains.csv")
        Export-PerUserRegistry -EnumerateSubKeys -OutputFile $OutputFile -SubKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains'
    }

    function Get-BrowserAnalysis {
        param([string]$OutputFile = $null)
        $OutputFile = Join-Path -Path $InternetFolder -ChildPath "browser_analysis.txt"
        $SqlitePath = $global:Binaries["SQLite3"]
        $Names = Get-ChildItem -Path "C:\Users"

        foreach ($Name in $Names) {
            $FullUserPath = Join-Path -Path "C:\Users" -ChildPath $Name
            # List of browser paths
            $BrowserPaths = @{
                "Chrome" = "\AppData\Local\Google\Chrome\User Data\Default\History"
                "Brave"  = "AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\History"
                "Edge"   = "AppData\Local\Microsoft\Edge\User Data\Default\History"
                #"Opera" = "AppData\Roaming\Opera Software\Opera Stable\Default\History"
                "Firefox" = "AppData\Roaming\Mozilla\Firefox\Profiles\*\places.sqlite"
            }

            # Make single search for each browser path
            foreach ($BrowserName in $BrowserPaths.Keys) {
                # Full path to chech each user for each browser path
                $UserWithBrowserPath = Join-Path -Path $FullUserPath -ChildPath $BrowserPaths[$BrowserName]

                # If the user have the browser path.
                if (Test-Path $UserWithBrowserPath) {
                    $AnalysisParentDir = Join-path -Path $InternetFolder -ChildPath "Browser_Analysis"
                    $null = New-Item -ItemType Directory -Path $AnalysisParentDir -Force

                    $AnalysisBrowserDir = Join-Path -Path $AnalysisParentDir -ChildPath $BrowserName
                    $null = New-Item -ItemType Directory -Path $AnalysisBrowserDir -Force

                    Copy-Item -Path $UserWithBrowserPath -Destination "$AnalysisBrowserDir\$Name-$BrowserName-History-File.sqlite"

                    $UrlOutputFile = Join-Path -Path $AnalysisBrowserDir -ChildPath "$Name-$BrowserName-Url_analysis.txt"
                    $KeywordOutputFile = Join-Path -Path $AnalysisBrowserDir -ChildPath "$Name-$BrowserName-keyword_search_term_analysis.txt"
                    $DownloadOutputFile = Join-Path -Path $AnalysisBrowserDir -ChildPath "$Name-$BrowserName-download-analysis.txt"
                    $Db = Join-Path -Path $AnalysisBrowserDir -ChildPath "$Name-$BrowserName-History-File.sqlite"

                    $UrlQuery   = "SELECT datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch') AS 'Visit Time UTC Form', substr(datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch', '+3 hours'), 12, 8) AS 'GMT+3 IL', substr(datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch', '+2 hours'), 12, 8) AS 'GMT+2 IL', visit_count AS 'Count', SUBSTR(title, 1, 90) AS 'URL Title', url AS 'Full URL' FROM urls ORDER BY last_visit_time DESC"
                    $UrlCommand = "$SqlitePath `"$Db`" `"$UrlQuery`""
                    $UrlData    = &($UrlCommand)
                    Write-OutputToFile -Command $UrlCommand -Data $UrlData -OutputFile $UrlOutputFile

                    $KeywordQuery   = "SELECT url_id AS 'Term ID', term AS 'Browser Keyword Search Term' FROM keyword_search_terms ORDER BY url_id DESC"
                    $KeywordCommand = "$SqlitePath `"$Db`" `"$KeywordQuery`""
                    $KeywordData    = &($KeywordCommand)
                    Write-OutputToFile -Command $KeywordCommand -Data $KeywordData -OutputFile $KeywordOutputFile

                    $DownloadQuery = "SELECT datetime((start_time / 1000000) - 11644473600, 'unixepoch') AS 'Download Start Time', strftime('%H:%M:S', (end_time / 1000000) - 11644473600, 'unixepoch') AS 'End Time', (ROUND(total_bytes / 1048576.0, 3) || ' MB') AS 'File Size', SUBSTR(mime_type, 1, 30) AS 'File Type', CASE WHEN opened = 1 THEN 'Yes' WHEN opened = 0 THEN 'No' ELSE opened END AS 'Opened From Browser?', current_path AS 'Path Of The Downloaded File', tab_url AS 'File Was Downloaded From This Link' FROM downloads ORDER BY start_time DESC"
                    $DownloadCommand = "$SqlitePath `"$Db`" `"$DownloadQuery`""
                    $DownloadData    = &($DownloadCommand)
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
        Invoke-ScriptBlock -Action $Task.key -FunctionMessage $Task.value[0] -OutputFile $Task.value[1]
    }
}


#TODO -- Fix the following error:
<#
Execution failed during 'Invoke-ScriptBlock'. Error => The term 'Y:\Proton Drive\My files\__001_MyGitHubRepos\WinTriageScript\bin\sqlite3.exe "Y:\Proton Drive\My files\__001_MyGitHubRepos\WinTriageScript\20261002_072917_192.168.1.19_MAS-4N6-BOX\010_Internet\Browser_Analysis\Edge\digintel-Edge-History-File.sqlite" "SELECT datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch') AS 'Visit Time UTC Form', substr(datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch', '+3 hours'), 12, 8) AS 'GMT+3 IL', substr(datetime((last_visit_time / 1000000) - 11644473600, 'unixepoch', '+2 hours'), 12, 8) AS 'GMT+2 IL', visit_count AS 'Count', SUBSTR(title, 1, 90) AS 'URL Title', url AS 'Full URL' FROM urls ORDER BY last_visit_time DESC"' is not recognized as the name of a cmdlet, function, script file, or operable program. Check the spelling of the name, or if a path was included, verify that the path is correct and try again.
#>