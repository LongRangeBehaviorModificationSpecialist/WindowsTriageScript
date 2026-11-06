function Get-TriageUserData {
    <#
    .SYNOPSIS
        Collects information about user accounts, groups, logon sessions,
        terminal sessions, and PowerShell command history (module 002_Users).

    .DESCRIPTION
        Runs a series of read-only collection tasks and writes the results
        to the module folder:

            02.01_who_am_I.txt
                `whoami /ALL`: the SID, group memberships, and privileges
                of the account running the toolkit.
            02.02_win32_user_profile.txt
                User profiles (`Win32_UserProfile`), including profile paths
                and last-use times.
            02.03_local_users.csv
                Local user accounts (`Get-LocalUser`).
            02.04_user_groups.csv
                Groups (`Win32_Group`).
            02.05_win32_local_logons.txt
                Logon sessions (`Win32_LogonSession`).
            02.06_win32_user_account.txt
                Accounts (`Win32_UserAccount`).
            02.07a_powershell_history_all.txt,
            02.07b_powershell_history_manifest.csv
                PowerShell console history for every user (see below), plus a
                manifest with source path, timestamps, and hashes.
            02.08_terminal_sessions.txt
                Terminal (RDP and console) sessions, from `qwinsta`.

        For task 02.07, the function looks in every profile folder under
        `<system drive>\Users` for the PSReadLine history file used by Windows
        PowerShell 5.1 and by PowerShell 7.

        Each file found is copied, with `Copy-TriageFile`, to
        `PowerShell_History\<user>\<version>\` in the module folder, so the
        original timestamps and hashes are recorded in the manifest.

        All copies are then joined into one text file with a heading for each
        user and file.

        If none are found, the text file says so.

    .PARAMETER UserFolder
        Path of the folder where this module writes its files.

        `Invoke-DfirTriageScan` creates it as `<ResultsFolder>\002_Users`.

    .INPUTS
        None.

        This function does not accept pipeline input.

    .OUTPUTS
        None.

        Results are written to files in UserFolder, and progress is written
        to the screen and the log.

    .EXAMPLE
        Get-TriageUserData `
            -UserFolder "E:\Triage\Case-2026-0142\002_Users"

        Writes the 02.xx files, and a PowerShell_History subfolder of copied
        history files.

    .EXAMPLE
        Invoke-DfirTriageScan -ResultsFolder $Folder -Operator "J. Smith" `
            -CaseNumber "2026-0142" -Modules "002_Users"

        The usual way this module runs, on its own.

    .NOTES
        Requires an elevated session so that other users' profile folders can
        be read.

        The `whoami` and `qwinsta` copies from bin are found with
        `Get-TriageBinary`, which only works after
        `Initialize-TriageSystemTools` has run, so call this function through
        `Invoke-DfirTriageScan`.

        Command history is evidence of what a user typed, and PSReadLine
        history can be limited or turned off by the user.  A missing file
        does not prove that no commands were run.

        Each task is isolated: if one fails, the error is logged and the next
        task still runs.

        A task whose output file is missing or empty is also reported as an
        error.

    .LINK
        Invoke-DfirTriageScan

    .LINK
        Copy-TriageFile

    .LINK
        Invoke-TriageTaskList
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UserFolder
    )

    function Get-WhoAmI {
        param(
            [string]$TxtFile = (
                Join-Path -Path $UserFolder -ChildPath "02.01_who_am_I.txt"
            )
        )
        $Data = & (Get-TriageBinary "whoami") /ALL /FO LIST
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-Win32UserProfile {
        param(
            [string]$TxtFile = (
                Join-Path -Path $UserFolder -ChildPath "02.02_win32_user_profile.txt"
            )
        )
        $Data = Get-CimInstance -ClassName Win32_UserProfile | Select-Object -Property *
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-LocalUserData {
        param(
            [string]$CsvFile = (
                Join-Path -Path $UserFolder -ChildPath "02.03_local_users.csv"
            )
        )
        $Data = Get-LocalUser |
            Select-Object -Property Name, FullName, SID, Description, Enabled, `
            LastLogon, PasswordRequired, PasswordLastSet, PasswordExpires, `
            PasswordChangableDate, UserMayChangePassword, AccountExpires, `
            PrincipalSource, ObjectClass |
            Sort-Object -Property Name
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile
    }


    function Get-UserGroups {
        param(
            [string]$CsvFile = (
                Join-Path -Path $UserFolder -ChildPath "02.04_user_groups.csv"
            )
        )
        $Data = Get-CimInstance -ClassName Win32_Group | Select-Object -Property *
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile
    }


    function Get-Win32LocalLogons {
        param(
            [string]$TxtFile = (
                Join-Path -Path $UserFolder -ChildPath "02.05_win32_local_logons.txt"
            )
        )
        $Data = Get-CimInstance -ClassName Win32_LogonSession | Select-Object -Property *
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-Win32UserAccount {
        param(
            [string]$TxtFile = (
                Join-Path -Path $UserFolder -ChildPath "02.06_win32_user_account.txt"
            )
        )
        $Data = Get-CimInstance -ClassName Win32_UserAccount | Select-Object -Property *
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-PowershellConsoleHistoryAllUsers {
        param(
            [string]$TxtFile = (
                Join-Path -Path $UserFolder -ChildPath "02.07a_powershell_history_all.txt"
            ),
            [string]$CopyFolder = (
                Join-Path -Path $UserFolder -ChildPath "PowerShell_History"
            ),
            [string]$ManifestCsv = (
                Join-Path -Path $UserFolder -ChildPath "02.07b_powershell_history_manifest.csv"
            )
        )
        # Profiles found by the hive step (includes profiles outside C:\Users)
        # Fall back to C:\Users
        $Profiles = @(
            $global:TriageUserHives |
            Where-Object ProfilePath |
            ForEach-Object { $_.ProfilePath } |
            Sort-Object -Unique
        )

        if ($Profiles.Count -eq 0) {
            $Profiles = @(
                Get-ChildItem -LiteralPath (Join-Path -Path $env:SystemDrive -ChildPath "Users") `
                    -Directory -Force | ForEach-Object { $_.FullName }
            )
        }

        $HistoryDirs = [ordered]@{
            "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine" = "WindowsPowerShell_5.1"
            "AppData\Roaming\Microsoft\PowerShell\PSReadLine"         = "PowerShell_7"
        }

        $null = New-Item -ItemType Directory -Path $CopyFolder -Force
        $Rows = [System.Collections.Generic.List[object]]::new()

        foreach ($ProfilePath in $Profiles) {
            $UserLeaf = Split-Path -Path $ProfilePath -Leaf

            foreach ($Rel in $HistoryDirs.Keys) {
                $Label = $HistoryDirs[$Rel]
                $Dir   = Join-Path -Path $ProfilePath -ChildPath $Rel
                if (-not (Test-Path -LiteralPath $Dir -PathType Container)) {
                    continue
                }

                # _history.txt also catches the VS Code terminal history file
                foreach ($File in Get-ChildItem `
                        -LiteralPath $Dir `
                        -Filter "*_history.txt" `
                        -File `
                        -Force `
                        -ErrorAction SilentlyContinue) {
                    $RelCopy = "PowerShell_History\$UserLeaf\$Label\$( $File.Name )"
                    $Dest    = Join-Path -Path $UserFolder -ChildPath $RelCopy

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

                    if ($R.Status -eq "OK") {
                        # Combined text file, built from the copy and streamed
                        # line by line
                        if (-not (Test-Path -LiteralPath $TxtFile)) {
                            Set-Content `
                                -LiteralPath $TxtFile `
                                -Value "PowerShell console history, one section per history file." `
                                -Encoding UTF8
                        }
                        Add-Content `
                            -LiteralPath $TxtFile `
                            -Value "`r`n===== $UserLeaf | $Label | $( $File.Name ) =====" `
                            -Encoding UTF8
                        Get-Content `
                            -LiteralPath $Dest |
                            Add-Content -LiteralPath $TxtFile -Encoding UTF8
                    }
                    else {
                        $NoCopyMsg = "Could not copy [ $( $File.FullName ) ] => $( $R.Detail )"
                        Show-Message -Message $NoCopyMsg -Level ERROR -AddToLog
                    }
                }
            }
        }

        if (-not (Test-Path -LiteralPath $TxtFile)) {
            Set-Content -LiteralPath $TxtFile -Value "No PowerShell history files were found." -Encoding UTF8
        }
        Write-OutputToCsv -Data $Rows -OutputFile $ManifestCsv
    }


    function Get-TerminalSessions {
        param(
            [string]$TxtFile = (
                Join-Path -Path $UserFolder -ChildPath "02.08_terminal_sessions.txt"
            )
        )
        $Data = & (Get-TriageBinary "qwinsta") 2>&1
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $Tasks = @(
        @{
            Action    = { Get-WhoAmI }
            Message   = "02.01_Getting WhoAmI Data..."
            Files     = "02.01_who_am_I.txt"
        }
        @{
            Action    = { Get-Win32UserProfile }
            Message   = "02.02_Getting Win32 User Profile Data..."
            Files     = "02.02_win32_user_profile.txt"
        }
        @{
            Action    = { Get-LocalUserData }
            Message   = "02.03_Getting Local Users List..."
            Files     = "02.03_local_users.csv"
        }
        @{
            Action    = { Get-UserGroups }
            Message   = "02.04_Getting User Groups..."
            Files     = "02.04_user_groups.csv"
        }
        @{
            Action    = { Get-Win32LocalLogons }
            Message   = "02.05_Getting Win32 Local Logons..."
            Files     = "02.05_win32_local_logons.txt"
        }
        @{
            Action    = { Get-Win32UserAccount }
            Message   = "02.06_Getting Win32 User Account Data..."
            Files     = "02.06_win32_user_account.txt"
        }
        @{
            Action    = { Get-PowershellConsoleHistoryAllUsers }
            Message   = "02.07_Getting PowerShell History (All Users)..."
            Files     = "02.07a_powershell_history_all.txt",
                        "02.07b_powershell_history_manifest.csv"
        }
        @{
            Action    = { Get-TerminalSessions }
            Message   = "02.08_Getting terminal sessions..."
            Files     = "02.08_terminal_sessions.txt"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $UserFolder

}
