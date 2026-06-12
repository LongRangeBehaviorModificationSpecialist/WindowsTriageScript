function Get-TriageUserData {
    [CmdletBinding()]
    param(
        [string]$userFolder
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


    function Get-WhoAmI {
        param(
            [string]$outputFile = "$userFolder\who_am_I.txt"
        )
        $command = { whoami /ALL /FO LIST }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-Win32UserProfile {
        param(
            [string]$outputFile = "$userFolder\win32_user_profile.txt"
        )
        $command = { Get-CimInstance -ClassName Win32_UserProfile | Select-Object -Property * }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-LocalUserData {
        param(
            [string]$outputFile = "$userFolder\local_users.txt"
        )
        $command = { Get-LocalUser | Select-Object -Property * | Format-List }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-UserGroups {
        param(
            [string]$outputFile = "$userFolder\user_groups.txt"
        )
        $command = { Get-WMIObject -Class Win32_Group | Select-Object -Property * }
        $data = &($command)
        Save-OutputAsCsv -Data $data -OutputFile $outputFile
    }


    function Get-Win32LocalLogons {
        param(
            [string]$outputFile = "$userFolder\win32_local_logons.txt"
        )
        $command = { Get-CimInstance -ClassName Win32_LogonSession | Select-Object -Property * }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-Win32UserAccount {
        param(
            [string]$outputFile = "$userFolder\win32_user_account.txt"
        )
        $command = { Get-CimInstance -ClassName Win32_UserAccount | Select-Object -Property * }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-PowershellConsoleHistoryAllUsers {
        param(
            [string]$outputFile = "$userFolder\powershell_history_all_users.txt"
        )
        $userDirs = Get-ChildItem -Path "C:\Users" -Directory

        foreach ($userDir in $userDirs) {
            if ($userDir.Count -eq 0) {
                $noDataFoundMsg = "No data found when running the $($MyInvocation.MyCommand.Name) command"
                Show-MessageAndWriteLogEntry -Message $noDataFoundMsg -Level INFO
            }
            else {
                $userName = "User.$userDir"
                $HistoryFilePath = Join-Path -Path $userDir.FullName -ChildPath "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
                # $PsHistoryFileName = [System.IO.Path]::GetFileName($HistoryFilePath)
                if (Test-Path -Path $HistoryFilePath -PathType Leaf) {
                    $outputDir = New-Item -ItemType Directory -Path $userFolder -Name $userName
                    Copy-Item -Path $HistoryFilePath -Destination $outputDir -Force
                    # $file = "$(Split-Path $outputDir -Leaf)\$PsHistoryFileName"
                }
            }
        }
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $workFlow = [ordered]@{
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
            "user_groups.txt"
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

    foreach ($task in $workFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
