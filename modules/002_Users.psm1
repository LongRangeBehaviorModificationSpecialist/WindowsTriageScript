function Get-TriageUserData {
    [CmdletBinding()]
    param([string]$UserFolder)

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

    function Get-WhoAmI {
        param([string]$OutputFile = "$UserFolder\who_am_I.txt")
        $Command =  { whoami /ALL /FO LIST }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-Win32UserProfile {
        param([string]$OutputFile = "$UserFolder\win32_user_profile.txt")
        $Command = { Get-CimInstance -ClassName Win32_UserProfile | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-LocalUserData {
        param([string]$OutputFile = "$UserFolder\local_users.txt")
        $Command = { Get-LocalUser | Select-Object -Property * | Format-List }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-UserGroups {
        param([string]$OutputFile = "$UserFolder\user_groups.csv")
        $Command = { Get-CimInstance -ClassName Win32_Group | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-Win32LocalLogons {
        param([string]$OutputFile = "$UserFolder\win32_local_logons.txt")
        $Command = { Get-CimInstance -ClassName Win32_LogonSession | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-Win32UserAccount {
        param([string]$OutputFile = "$UserFolder\win32_user_account.txt")
        $Command = { Get-CimInstance -ClassName Win32_UserAccount | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-PowershellConsoleHistoryAllUsers {
        param([string]$OutputFile = "$UserFolder\powershell_history_all_users.txt")
        $UserDirs = Get-ChildItem -Path "C:\Users" -Directory

        foreach ($UserDir in $UserDirs) {
            if ($UserDir.Count -eq 0) {
                $NoDataFoundMsg = "No data was found when running the '$( $MyInvocation.MyCommand.Name )' command."
                Show-Message -Message $NoDataFoundMsg -Level INFO -AddToLog -MessageColor Yellow
            }
            else {
                $UserName = "User.$UserDir"
                $HistoryFilePath = Join-Path -Path $UserDir.FullName -ChildPath "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
                # $PsHistoryFileName = [System.IO.Path]::GetFileName($HistoryFilePath)
                if (Test-Path -Path $HistoryFilePath -PathType Leaf) {
                    $OutputDir = New-Item -ItemType Directory -Path $UserFolder -Name $UserName
                    Copy-Item -Path $HistoryFilePath -Destination $OutputDir -Force
                    # $File = "$(Split-Path $OutputDir -Leaf)\$PsHistoryFileName"
                }
            }
        }
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $UsersWorkFlow = [ordered]@{
        { Get-WhoAmI } = (
            "Getting WhoAmI Data...",
            "who_am_I.txt"
        )
        { Get-Win32UserProfile } = (
            "Getting Win32 User Profile Data...",
            "win32_user_profile.txt"
        )
        { Get-LocalUserData } = (
            "Getting Local Users List...",
            "local_users.txt"
        )
        { Get-UserGroups } = (
            "Getting User Groups...",
            "user_groups.csv"
        )
        { Get-Win32LocalLogons } = (
            "Getting Win32 Local Logons...",
            "win32_local_logons.txt"
        )
        { Get-Win32UserAccount } = (
            "Getting Win32 User Account Data...",
            "win32_user_account.txt"
        )
        { Get-PowershellConsoleHistoryAllUsers } = (
            "Getting PowerShell History (All Users)...",
            "powershell_history_all_users.txt"
        )
    }

    foreach ($Task in $UsersWorkFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $Task.key -FunctionMessage $Task.value[0] -OutputFile $Task.value[1]
    }
}
