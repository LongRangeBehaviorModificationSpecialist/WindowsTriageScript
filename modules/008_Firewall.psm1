function Get-TriageFirewallData {
    [CmdletBinding()]
    param(
        [string]$firewallFolder
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


    function Get-FirewallRules {
        param(
            [string]$outputFile = "$firewallFolder\firewall_rules.txt"
        )
        $command =  { netsh advfirewall firewall show rule name=all verbose }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-DefenderExclusions {
        param(
            [string]$outputFile = "$firewallFolder\defender_preferences.txt"
        )
        $command =  { Get-MpPreference |
                        Select-Object -Property *
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }

    function Copy-DefenderLogs {
        param(
            [string]$outputFile = "$firewallFolder\defender_log_file_list.txt"
        )
        Show-MessageAndWriteLogEntry -Message "Copying Windows Defender Log Files..." -Level INFO

        $mpOutputFolder = Join-Path -Path $firewallFolder -ChildPath "Defender_Log_Files"
        $null = New-Item -ItemType Directory -Name $mpOutputFolder -Force

        $mpLogLocation = "C:\ProgramData\Microsoft\Windows Defender\Support"
        $mpLogFiles = Get-ChildItem -Path $mpLogLocation -Name "*.log"

        foreach ($file in $mpLogFiles) {
            Copy-Item -Path $file -Destination $mpOutputFolder
            Add-Content -Path $outputFile -Value "$($file.Name)" -Encoding UTF8 -Force
        }

        Show-MessageAndWriteLogEntry -File $outputFile -Level SUCCESS
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $workFlow = [ordered]@{
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

    foreach ($task in $workFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }

    Copy-DefenderLogs
}
