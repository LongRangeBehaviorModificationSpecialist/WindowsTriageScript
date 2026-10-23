function Get-TriageFirewallData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FirewallFolder
    )
    begin {
        function Get-FirewallRules {
            param(
                [string]$TxtFile = (Join-Path -Path $FirewallFolder -ChildPath "firewall_rules.txt")
            )
            $Data = & (Get-TriageBinary "netsh") advfirewall firewall show rule name=all verbose
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-DefenderPreferences {
            param(
                [string]$TxtFile = (Join-Path -Path $FirewallFolder -ChildPath "defender_preferences.txt")
            )
            $Data = Get-MpPreference | Select-Object -Property *
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Copy-DefenderLogs {
            param(
                [string]$TxtFile = (Join-Path -Path $FirewallFolder -ChildPath "defender_log_files.txt")
            )

            $MpOutputFolder = Join-Path -Path $FirewallFolder -ChildPath "Defender_Log_Files"
            $null = New-Item -ItemType Directory -Path $MpOutputFolder -Force

            $MpLogLocation = "$env:ProgramData\Microsoft\Windows Defender\Support"
            $MpLogFiles = Get-ChildItem -LiteralPath $MpLogLocation -Filter "*.log" -File

            foreach ($File in $MpLogFiles) {
                Copy-Item -LiteralPath $File.FullName -Destination $MpOutputFolder
                Add-Content -Path $TxtFile -Value $File.FullName -Encoding UTF8 -Force
            }
        }

        function Get-DefenderDetections {
            param(
                [string]$ThreatDetectionsFile = (
                    Join-Path -Path $FirewallFolder -ChildPath "defender_threat_detections.csv"
                ),
                [string]$ThreatsFile = (Join-Path -Path $FirewallFolder -ChildPath "defender_threats.csv"),
                [string]$StatusFile = (Join-Path -Path $FirewallFolder -ChildPath "defender_status.txt")
            )
            $Skip = "CimClass", "CimInstanceProperties", "CimSystemProperties"
            $Detections = Get-MpThreatDetection -ErrorAction SilentlyContinue |
                Select-Object -Property *, @{ N = "ResourceList"; E = { @($_.Resources) -join "; " } } -ExcludeProperty ($Skip + "Resources")

            $Threats = Get-MpThreat -ErrorAction SilentlyContinue |
                Select-Object -Property *, @{ N = "ResourceList"; E = { @($_.Resources) -join "; " } } -ExcludeProperty ($Skip + "Resources")

            Write-OutputToCsv -Data $Detections -OutputFile $ThreatDetectionsFile
            Write-OutputToCsv -Data $Threats -OutputFile $ThreatsFile

            $Status = Get-MpComputerStatus -ErrorAction SilentlyContinue | Out-String -Width 4096

            Write-OutputToFile -Data $Status -OutputFile $StatusFile
        }
    }
    process {
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
            @{
                Action  = { Get-DefenderDetections }
                Message = "Listing Windows Defender Detections..."
                Files   = "defender_threat_detections.csv", "defender_threats.csv", "defender_status.txt"
            }
        )
        Invoke-TriageTaskList -Tasks $Tasks -Folder $FirewallFolder
    }
}
