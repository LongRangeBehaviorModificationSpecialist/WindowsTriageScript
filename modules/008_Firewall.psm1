function Get-TriageFirewallData {
    [CmdletBinding()]

    param([string]$FirewallFolder)

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
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error -> $( $_.Exception.Message )"
            Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
        }
    }

    function Get-FirewallRules {
        param([string]$OutputFile = "$FirewallFolder\firewall_rules.txt")
        $Command = { netsh advfirewall firewall show rule name=all verbose }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-DefenderExclusions {
        param([string]$OutputFile = "$FirewallFolder\defender_preferences.txt")
        $Command = { Get-MpPreference | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Copy-DefenderLogs {
        param([string]$OutputFile = "$FirewallFolder\defender_log_file_list.txt")
        Show-Message -Message "Copying Windows Defender Log Files..." -Level INFO -AddToLog

        $MpOutputFolder = Join-Path -Path $FirewallFolder -ChildPath "Defender_Log_Files"
        $null           = New-Item -ItemType Directory -Path $MpOutputFolder -Force

        $MpLogLocation = "C:\ProgramData\Microsoft\Windows Defender\Support"
        $MpLogFiles    = Get-ChildItem -Path $MpLogLocation -Name "*.log"

        foreach ($File in $MpLogFiles) {
            Copy-Item -Path $File -Destination $MpOutputFolder
            Add-Content -Path $OutputFile -Value "$($File.Name)" -Encoding UTF8 -Force
        }

        Show-Message -File $OutputFile -Level SUCCESS -AddToLog
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $FirewallWorkFlow = [ordered]@{
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

    foreach ($Task in $FirewallWorkFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $Task.key -FunctionMessage $Task.value[0] -OutputFile $Task.value[1]
    }

    Copy-DefenderLogs
}
