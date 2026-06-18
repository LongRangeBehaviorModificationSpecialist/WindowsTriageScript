function Get-TriageUserData {
    [CmdletBinding()]
    param(
        [string]$user_folder
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


    function Get-WhoAmI {
        param(
            [string]$output_file = "$user_folder\who_am_I.txt"
        )
        $command =  { whoami /ALL /FO LIST }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-Win32UserProfile {
        param(
            [string]$output_file = "$user_folder\win32_user_profile.txt"
        )
        $command =  { Get-CimInstance -ClassName Win32_UserProfile |
                        Select-Object -Property *
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-LocalUserData {
        param(
            [string]$output_file = "$user_folder\local_users.txt"
        )
        $command =  { Get-LocalUser |
                        Select-Object -Property * |
                        Format-List
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-UserGroups {
        param(
            [string]$output_file = "$user_folder\user_groups.csv"
        )
        $command =  { Get-CimInstance -ClassName Win32_Group |
                        Select-Object -Property *
                    }
        $data = &($command)
        Write-OutputToCsv -Data $data -OutputFile $output_file
    }


    function Get-Win32LocalLogons {
        param(
            [string]$output_file = "$user_folder\win32_local_logons.txt"
        )
        $command =  { Get-CimInstance -ClassName Win32_LogonSession |
                        Select-Object -Property *
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-Win32UserAccount {
        param(
            [string]$output_file = "$user_folder\win32_user_account.txt"
        )
        $command =  { Get-CimInstance -ClassName Win32_UserAccount |
                        Select-Object -Property *
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-PowershellConsoleHistoryAllUsers {
        param(
            [string]$output_file = "$user_folder\powershell_history_all_users.txt"
        )
        $user_dirs = Get-ChildItem -Path "C:\Users" -Directory

        foreach ($user_dir in $user_dirs) {
            if ($user_dir.Count -eq 0) {
                $no_data_found_msg = "No data found when running the $($MyInvocation.MyCommand.Name) command"
                Show-MessageAndWriteLogEntry -Msg $no_data_found_msg -Level INFO
            }
            else {
                $user_name = "User.$user_dir"
                $history_file_path = Join-Path -Path $user_dir.FullName -ChildPath "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
                # $ps_history_file_name = [System.IO.Path]::GetFileName($history_file_path)
                if (Test-Path -Path $history_file_path -PathType Leaf) {
                    $output_dir = New-Item -ItemType Directory -Path $user_folder -Name $user_name
                    Copy-Item -Path $history_file_path -Destination $output_dir -Force
                    # $file = "$(Split-Path $output_dir -Leaf)\$ps_history_file_name"
                }
            }
        }
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $users_work_flow = [ordered]@{
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

    foreach ($task in $users_work_flow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
