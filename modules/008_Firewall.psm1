function Get-TriageFirewallData {
    [CmdletBinding()]
    param(
        [string]$FirewallFolder
    )

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

    $Tasks = @(
        @{
            Action  = { Get-FirewallRules }
            Message = "Getting Device Firewall Configuration..."
            Files   = "firewall_rules.txt"
        }
        @{
            Action  = { Get-DefenderPreferences }
            Message = "Parsing Windows Defender Preferences..."
            Files   = "defender_preferences.txt"
        }
        @{
            Action  = { Copy-DefenderLogs }
            Message = "Copying Windows Defender Log Files..."
            Files   = "defender_log_files.txt"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $FirewallFolder
}
