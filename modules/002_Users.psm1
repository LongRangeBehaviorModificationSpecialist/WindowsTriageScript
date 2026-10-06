function Get-TriageUserData {
    [CmdletBinding()]
    param(
        [string]$UserFolder
    )

    function Get-WhoAmI {
        param(
            [string]$OutputFile = "$UserFolder\who_am_I.txt"
        )
        $Command =  { & (Get-TriageBinary "whoami") /ALL /FO LIST }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-Win32UserProfile {
        param(
            [string]$OutputFile = "$UserFolder\win32_user_profile.txt"
        )
        $Command = { Get-CimInstance -ClassName Win32_UserProfile | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-LocalUserData {
        param(
            [string]$OutputFile = "$UserFolder\local_users.txt"
        )
        $Command = { Get-LocalUser | Select-Object -Property * | Format-List }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-UserGroups {
        param(
            [string]$OutputFile = "$UserFolder\user_groups.csv"
        )
        $Command = { Get-CimInstance -ClassName Win32_Group | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-Win32LocalLogons {
        param(
            [string]$OutputFile = "$UserFolder\win32_local_logons.txt"
        )
        $Command = { Get-CimInstance -ClassName Win32_LogonSession | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-Win32UserAccount {
        param(
            [string]$OutputFile = "$UserFolder\win32_user_account.txt"
        )
        $Command = { Get-CimInstance -ClassName Win32_UserAccount | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    #TODO -- Check function
    function Get-PowershellConsoleHistoryAllUsers {
        param(
            [string]$OutputFile = "$UserFolder\powershell_history_all_users.txt"
        )
        $Target = Join-Path -Path $env:SystemDrive -ChildPath "Users"
        $UserDirs = Get-ChildItem -LiteralPath $Target -Directory

        foreach ($UserDir in $UserDirs) {
            $UserName = "User.$UserDir"
            $HistoryFilePath = Join-Path -Path $UserDir.FullName -ChildPath "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
            # $PsHistoryFileName = [System.IO.Path]::GetFileName($HistoryFilePath)
            if (Test-Path -Path $HistoryFilePath -PathType Leaf) {
                $OutputDir = New-Item -ItemType Directory -Path $UserFolder -Name $UserName -Force
                Copy-Item -Path $HistoryFilePath -Destination $OutputDir -Force
                # $File = "$(Split-Path $OutputDir -Leaf)\$PsHistoryFileName"
            }
        }
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
            Files   = "powershell_history_all_users.txt"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $UserFolder

}
