function Get-TriageFirewallData {
    [CmdletBinding()]
    param(
        [string]$FirewallFolder
    )


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$Action,
            [string]$FunctionMsg,
            [string]$OutputFile
        )
        try {
            Show-MessageAndWriteLogEntry -Msg $FunctionMsg -Level INFO
            & $Action
            Show-MessageAndWriteLogEntry -File $OutputFile -Level SUCCESS
        }
        catch {
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error: $( $_.Exception.Message )"
            Show-MessageAndWriteLogEntry -Msg $ErrorMsg -Level ERROR
        }
    }


    function Get-FirewallRules {
        param(
            [string]$OutputFile = "$FirewallFolder\firewall_rules.txt"
        )
        $Command =  { netsh advfirewall firewall show rule name=all verbose }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-DefenderExclusions {
        param(
            [string]$OutputFile = "$FirewallFolder\defender_preferences.txt"
        )
        $Command =  { Get-MpPreference |
                        Select-Object -Property *
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Copy-DefenderLogs {
        param(
            [string]$OutputFile = "$FirewallFolder\defender_log_file_list.txt"
        )
        Show-MessageAndWriteLogEntry -Msg "Copying Windows Defender Log Files..." -Level INFO

        $MpOutputFolder = Join-Path -Path $FirewallFolder -ChildPath "Defender_Log_Files"
        $null           = New-Item -ItemType Directory -Name $MpOutputFolder -Force

        $MpLogLocation = "C:\ProgramData\Microsoft\Windows Defender\Support"
        $MpLogFiles    = Get-ChildItem -Path $MpLogLocation -Name "*.log"

        foreach ($File in $MpLogFiles) {
            Copy-Item -Path $File -Destination $MpOutputFolder
            Add-Content -Path $OutputFile -Value "$($File.Name)" -Encoding UTF8 -Force
        }

        Show-MessageAndWriteLogEntry -File $OutputFile -Level SUCCESS
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $firewallWorkFlow = [ordered]@{
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

    foreach ($Task in $firewallWorkFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $Task.key -functionMsg $Task.value[0] -OutputFile $Task.value[1]
    }

    Copy-DefenderLogs
}
