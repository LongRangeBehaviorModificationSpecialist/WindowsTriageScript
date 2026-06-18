function Get-TriageFirewallData {
    [CmdletBinding()]
    param(
        [string]$firewall_folder
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


    function Get-FirewallRules {
        param(
            [string]$output_file = "$firewall_folder\firewall_rules.txt"
        )
        $command =  { netsh advfirewall firewall show rule name=all verbose }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-DefenderExclusions {
        param(
            [string]$output_file = "$firewall_folder\defender_preferences.txt"
        )
        $command =  { Get-MpPreference |
                        Select-Object -Property *
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }

    function Copy-DefenderLogs {
        param(
            [string]$output_file = "$firewall_folder\defender_log_file_list.txt"
        )
        Show-MessageAndWriteLogEntry -Msg "Copying Windows Defender Log Files..." -Level INFO

        $mp_output_folder = Join-Path -Path $firewall_folder -ChildPath "Defender_Log_Files"
        $null             = New-Item -ItemType Directory -Name $mp_output_folder -Force

        $mp_log_location = "C:\ProgramData\Microsoft\Windows Defender\Support"
        $mp_log_files    = Get-ChildItem -Path $mp_log_location -Name "*.log"

        foreach ($file in $mp_log_files) {
            Copy-Item -Path $file -Destination $mp_output_folder
            Add-Content -Path $output_file -Value "$($file.Name)" -Encoding UTF8 -Force
        }

        Show-MessageAndWriteLogEntry -File $output_file -Level SUCCESS
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $firewall_work_flow = [ordered]@{
        { Get-FirewallRules } = (
            "Getting Device Firewall Configuration...",
            "firewall_rules.txt"
        )
        { Get-DefenderExclusions } = (
            "Parsing Windows Defender Preferences...",
            "defender_preferences.txt"
        )
        # { Copy-DefenderLogs } = (
        #     "Copying Windows Defender Log Files...",
        #     "defender_log_files.txt"
        # )
    }

    foreach ($task in $firewall_work_flow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }

    Copy-DefenderLogs
}
