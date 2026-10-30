function Get-TriageUserData
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserFolder
    )

    begin
    {
        function Get-WhoAmI
        {
            param(
                [string]$TxtFile = (Join-Path -Path $UserFolder -ChildPath "02.01_who_am_I.txt")
            )

            $Data = & (Get-TriageBinary "whoami") /ALL /FO LIST
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-Win32UserProfile
        {
            param(
                [string]$TxtFile = (Join-Path -Path $UserFolder -ChildPath "02.02_win32_user_profile.txt")
            )

            $Data = & { Get-CimInstance -ClassName Win32_UserProfile | Select-Object -Property * }
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-LocalUserData
        {
            param(
                [string]$TxtFile = (Join-Path -Path $UserFolder -ChildPath "02.03_local_users.txt")
            )

            $Data = & { Get-LocalUser | Select-Object -Property * | Format-List }
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-UserGroups
        {
            param(
                [string]$CsvFile = (Join-Path -Path $UserFolder -ChildPath "02.04_user_groups.csv")
            )

            $Data = & { Get-CimInstance -ClassName Win32_Group | Select-Object -Property * }
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-Win32LocalLogons
        {
            param(
                [string]$TxtFile = (Join-Path -Path $UserFolder -ChildPath "02.05_win32_local_logons.txt")
            )

            $Data = & { Get-CimInstance -ClassName Win32_LogonSession | Select-Object -Property * }
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-Win32UserAccount
        {
            param(
                [string]$TxtFile = (Join-Path -Path $UserFolder -ChildPath "02.06_win32_user_account.txt")
            )

            $Data = & { Get-CimInstance -ClassName Win32_UserAccount | Select-Object -Property * }
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-PowershellConsoleHistoryAllUsers
        {
            param(
                [string]$TxtFile = (Join-Path -Path $UserFolder -ChildPath "02.07a_powershell_history_all_users.txt"),
                [string]$CopyFolder = (Join-Path -Path $UserFolder -ChildPath "PowerShell_History")
            )

            # Profiles found by the hive step (includes profiles outside C:\Users)
            # Fall back to C:\Users
            $Profiles = @($global:TriageUserHives | Where-Object ProfilePath | ForEach-Object { $_.ProfilePath } | Sort-Object -Unique)

            if ($Profiles.Count -eq 0)
            {
                $Profiles = @(Get-ChildItem -LiteralPath (Join-Path -Path $env:SystemDrive -ChildPath "Users") -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
            }

            $HistoryDirs = [ordered]@{
                "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine" = "WindowsPowerShell_5.1"
                "AppData\Roaming\Microsoft\PowerShell\PSReadLine" = "PowerShell_7"
            }

            $null = New-Item -ItemType Directory -Path $CopyFolder -Force
            $Rows = [System.Collections.Generic.List[object]]::new()

            foreach ($ProfilePath in $Profiles)
            {
                $UserLeaf = Split-Path -Path $ProfilePath -Leaf

                foreach ($Rel in $HistoryDirs.Keys)
                {
                    $Label = $HistoryDirs[$Rel]
                    $Dir = Join-Path -Path $ProfilePath -ChildPath $Rel
                    if (-not (Test-Path -LiteralPath $Dir -PathType Container))
                    {
                        continue
                    }

                    # _history.txt also catches the VS Code terminal history file
                    foreach ($File in Get-ChildItem -LiteralPath $Dir -Filter "*_history.txt" -File -Force -ErrorAction SilentlyContinue)
                    {
                        $RelCopy = "PowerShell_History\$UserLeaf\$Label\$( $File.Name )"
                        $Dest = Join-Path -Path $UserFolder -ChildPath $RelCopy

                        $R = Copy-TriageFile -Source $File.FullName -Destination $Dest
                        $Rows.Add([PSCustomObject]@{
                            User              = $UserLeaf
                            Edition           = $Label
                            Source            = $File.FullName
                            CopiedTo          = $RelCopy
                            SizeBytes         = $R.SizeBytes
                            SourceModifiedUtc = $R.SourceModifiedUtc
                            Method            = $R.Method
                            Status            = $R.Status
                            Detail            = $R.Detail
                        })

                        if ($R.Status -eq "OK")
                        {
                            # Combined text file, built from the copy and streamed
                            # line by line
                            if (-not (Test-Path -LiteralPath $TxtFile))
                            {
                                Set-Content -LiteralPath $TxtFile -Value "PowerShell console history, one section per history file." -Encoding UTF8
                            }
                            Add-Content -LiteralPath $TxtFile -Value "`r`n===== $UserLeaf | $Label | $( $File.Name ) =====" -Encoding UTF8
                            Get-Content -LiteralPath $Dest | Add-Content -LiteralPath $TxtFile -Encoding UTF8
                        }
                        else
                        {
                            Show-Message -Message "Could not copy [ $( $File.FullName ) ] => $( $R.Detail )" -Level ERROR -AddToLog
                        }
                    }
                }
            }

            if (-not (Test-Path -LiteralPath $TxtFile))
            {
                Set-Content -LiteralPath $TxtFile -Value "No PowerShell history files were found." -Encoding UTF8
            }
            Write-OutputToCsv -Data $Rows -OutputFile (Join-Path -Path $UserFolder -ChildPath "02.07b_powershell_history_manifest.csv")
        }

        function Get-TerminalSessions
        {
            param(
                [string]$TxtFile = (Join-Path -Path $UserFolder -ChildPath "02.08_terminal_sessions.txt")
            )

            $Data = & (Get-TriageBinary "qwinsta") 2>&1
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }
    }
    process
    {
    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------
        $Tasks = @(
            @{
                Action  = { Get-WhoAmI }
                Message = "02.01_Getting WhoAmI Data..."
                Files   = "02.01_who_am_I.txt"
            }
            @{
                Action  = { Get-Win32UserProfile }
                Message = "02.02_Getting Win32 User Profile Data..."
                Files   = "02.02_win32_user_profile.txt"
            }
            @{
                Action  = { Get-LocalUserData }
                Message = "02.03_Getting Local Users List..."
                Files   = "02.03_local_users.txt"
            }
            @{
                Action  = { Get-UserGroups }
                Message = "02.04_Getting User Groups..."
                Files   = "02.04_user_groups.csv"
            }
            @{
                Action  = { Get-Win32LocalLogons }
                Message = "02.05_Getting Win32 Local Logons..."
                Files   = "02.05_win32_local_logons.txt"
            }
            @{
                Action  = { Get-Win32UserAccount }
                Message = "02.06_Getting Win32 User Account Data..."
                Files   = "02.06_win32_user_account.txt"
            }
            @{
                Action  = { Get-PowershellConsoleHistoryAllUsers }
                Message = "02.07_Getting PowerShell History (All Users)..."
                Files   = "02.07a_powershell_history_all_users.txt", "02.07b_powershell_history_manifest.csv"
            }
            @{
                Action  = { Get-TerminalSessions }
                Message = "02.08_Getting terminal sessions..."
                Files   = "02.08_terminal_sessions.txt"
            }
        )
        Invoke-TriageTaskList -Tasks $Tasks -Folder $UserFolder
    }
}
