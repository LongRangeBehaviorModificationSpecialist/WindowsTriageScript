function Get-TriageFirewallData {
    [CmdletBinding()]
    param(
        [string]$FirewallFolder
    )

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
            Show-Message -Message "Execution failed during $( $MyInvocation.MyCommand.Name ).  Error => $( $_.Exception.Message )" -Level ERROR -AddToLog
        }
    }

    function Get-FirewallRules {
        param(
            [string]$OutputFile = "$FirewallFolder\firewall_rules.txt"
        )
        $Command = { & (Get-TriageBinary "netsh")  advfirewall firewall show rule name=all verbose }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-DefenderPreferences {
        param(
            [string]$OutputFile = "$FirewallFolder\defender_preferences.txt"
        )
        $Command = { Get-MpPreference | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Copy-DefenderLogs {
        param(
            [string]$OutputFile = "$FirewallFolder\defender_log_files.txt"
        )

        $MpOutputFolder = Join-Path -Path $FirewallFolder -ChildPath "Defender_Log_Files"
        $null = New-Item -ItemType Directory -Path $MpOutputFolder -Force

        $MpLogLocation = "$env:ProgramData\Microsoft\Windows Defender\Support"
        $MpLogFiles = Get-ChildItem -LiteralPath $MpLogLocation -Filter "*.log" -File

        foreach ($File in $MpLogFiles) {
            Copy-Item -LiteralPath $File.FullName -Destination $MpOutputFolder
            Add-Content -Path $OutputFile -Value $File.FullName -Encoding UTF8 -Force
        }
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $FirewallWorkFlow = [ordered]@{
        { Get-FirewallRules } = (
            "Getting Device Firewall Configuration...",
            "firewall_rules.txt"
        )
        { Get-DefenderPreferences } = (
            "Parsing Windows Defender Preferences...",
            "defender_preferences.txt"
        )
        { Copy-DefenderLogs } = (
            "Copying Windows Defender Log Files...",
            "defender_log_files.txt"
        )
    }

    foreach ($Task in $FirewallWorkFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $Task.Key -FunctionMessage $Task.Value[0] -OutputFile $Task.Value[1]
    }
}
