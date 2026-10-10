function Get-TriageUserData {
    [CmdletBinding()]
    param(
        [string]$UserFolder
    )


    function Get-WhoAmI {
        param(
            [string]$TxtFile = Join-Path -Path $UserFolder -ChildPath "who_am_I.txt"
        )
        $Command = { & (Get-TriageBinary "whoami") /ALL /FO LIST }
        $Data = &($Command)
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-Win32UserProfile {
        param(
            [string]$TxtFile = Join-Path -Path $UserFolder -ChildPath "win32_user_profile.txt"
        )
        $Command = { Get-CimInstance -ClassName Win32_UserProfile | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-LocalUserData {
        param(
            [string]$TxtFile = Join-Path -Path $UserFolder -ChildPath "local_users.txt"
        )
        $Command = { Get-LocalUser | Select-Object -Property * | Format-List }
        $Data = &($Command)
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-UserGroups {
        param(
            [string]$CsvFile = Join-Path -Path $UserFolder -ChildPath "user_groups.csv"
        )
        $Command = { Get-CimInstance -ClassName Win32_Group | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile
    }


    function Get-Win32LocalLogons {
        param(
            [string]$TxtFile = Join-Path -Path $UserFolder -ChildPath "win32_local_logons.txt"
        )
        $Command = { Get-CimInstance -ClassName Win32_LogonSession | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-Win32UserAccount {
        param(
            [string]$TxtFile = Join-Path -Path $UserFolder -ChildPath "win32_user_account.txt"
        )
        $Command = { Get-CimInstance -ClassName Win32_UserAccount | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-PowershellConsoleHistoryAllUsers {
        param(
            [string]$TxtFile = Join-Path -Path $UserFolder -ChildPath "powershell_history_all_users.txt",
            [string]$CopyFolder = Join-Path -Path $UserFolder -ChildPath PowerShell_History"
        )
        # Profiles found by the hive step (includes profiles outside C:\Users)
        # Fall back to C:\Users
        $Profiles = @($global:TriageUserHives | Where-Object ProfilePath | ForEach-Object { $_.ProfilePath } | Sort-Object -Unique)
        if ($Profiles.Count -eq 0) {
            $Profiles = @(Get-ChildItem -LiteralPath (Join-Path -Path $env:SystemDrive -ChildPath "Users") -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        }

        $HistoryDirs = [ordered]@{
            "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine" = "WindowsPowerShell_5.1"
            "AppData\Roaming\Microsoft\PowerShell\PSReadLine" = "PowerShell_7"
        }

        $null = New-Item -ItemType Directory -Path $CopyFolder -Force
        $Rows = [System.Collections.Generic.List[object]]::new()

        foreach ($ProfilePath in $Profiles) {
            $UserLeaf = Split-Path -Path $ProfilePath -Leaf

            foreach ($Rel in $HistoryDirs.Keys) {
                $Label = $HistoryDirs[$Rel]
                $Dir = Join-Path -Path $ProfilePath -ChildPath $Rel
                if (-not (Test-Path -LiteralPath $Dir -PathType Container)) {
                    continue
                }

                # _history.txt also catches the VS Code terminal history file
                foreach ($File in Get-ChildItem -LiteralPath $Dir -Filter "*_history.txt" -File -Force -ErrorAction SilentlyContinue) {
                    $RelCopy = "PowerShell_History\$UserLeaf\$Label\$( $File.Name )"
                    $Dest = Join-Path -Path $UserFolder -ChildPath $RelCopy

                    $R = Copy-TriageFile -Source $File.FullName -Destination $Dest
                    $Rows.Add([pscustomobject]@{
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

                    if ($R.Status -eq "OK") {
                        # Combined text file, built from the copy and streamed
                        # line by line
                        if (-not (Test-Path -LiteralPath $OutputFile)) {
                            Set-Content -LiteralPath $TxtFile -Value "PowerShell console history, one section per history file." -Encoding UTF8
                        }
                        Add-Content -LiteralPath $TxtFile -Value "`r`n===== $UserLeaf | $Label | $( $File.Name ) =====" -Encoding UTF8
                        Get-Content -LiteralPath $Dest | Add-Content -LiteralPath $TxtFile -Encoding UTF8
                    }
                    else {
                        Show-Message -Message "Could not copy [ $( $File.FullName ) ] => $( $R.Detail )" -Level ERROR -AddToLog
                    }
                }
            }
        }

        if (-not (Test-Path -LiteralPath $OutputFile)) {
            Set-Content -LiteralPath $TxtFile -Value "No PowerShell history files were found." -Encoding UTF8
        }
        Write-OutputToCsv -Data $Rows -OutputFile (Join-Path -Path $UserFolder -ChildPath "powershell_history_manifest.csv")
    }


    function Get-TerminalSessions {
        param(
            [string]$TxtFile = Join-Path -Path $UserFolder -ChildPath "terminal_sessions.txt"
        )
        $Command = { & (Get-TriageBinary "qwinsta") 2>&1 | ForEach-Object { "$_" } }
        $Data = &($Command)
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $Tasks = @(
        @{
            Action  = { Get-WhoAmI }
            Message = "Getting WhoAmI Data..."
            Files   = "who_am_I.txt"
        }
        @{
            Action  = { Get-Win32UserProfile }
            Message = "Getting Win32 User Profile Data..."
            Files   = "win32_user_profile.txt"
        }
        @{
            Action  = { Get-LocalUserData }
            Message = "Getting Local Users List..."
            Files   = "local_users.txt"
        }
        @{
            Action  = { Get-UserGroups }
            Message = "Getting User Groups..."
            Files   = "user_groups.csv"
        }
        @{
            Action  = { Get-Win32LocalLogons }
            Message = "Getting Win32 Local Logons..."
            Files   = "win32_local_logons.txt"
        }
        @{
            Action  = { Get-Win32UserAccount }
            Message = "Getting Win32 User Account Data..."
            Files   = "win32_user_account.txt"
        }
        @{
            Action  = { Get-PowershellConsoleHistoryAllUsers }
            Message = "Getting PowerShell History (All Users)..."
            Files   = "powershell_history_all_users.txt", "powershell_history_manifest.csv"
        }
        @{
            Action  = { Get-TerminalSessions }
            Message = "Getting terminal sessions..."
            Files   = "terminal_sessions.txt"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $UserFolder
}
