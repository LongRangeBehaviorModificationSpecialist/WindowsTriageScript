function Get-TriageFirewallData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FirewallFolder
    )


    # 08.01
    function Get-FirewallRules {
        param([string]$OutputFile)

        $Data = & (Get-TriageBinary "netsh") advfirewall firewall show rule name=all verbose
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 08.02
    function Get-DefenderPreferences {
        param([string]$OutputFile)

        $Data = Get-MpPreference | Select-Object -Property *
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 08.03
    function Copy-DefenderLogs {
        param([string]$OutputFile)

        $MpOutputFolder = Join-Path -Path $FirewallFolder -ChildPath "Defender_Log_Files"
        $null = New-Item -ItemType Directory -Path $MpOutputFolder -Force

        $MpLogLocation = "$env:ProgramData\Microsoft\Windows Defender\Support"
        $MpLogFiles = Get-ChildItem -LiteralPath $MpLogLocation -Filter "*.log" -File

        foreach ($File in $MpLogFiles) {
            Copy-Item -LiteralPath $File.FullName -Destination $MpOutputFolder
            Add-Content -Path $OutputFile -Value $File.FullName -Encoding UTF8 -Force
        }
    }


    # 08.04
    function Get-DefenderDetections {
        param([string[]]$OutputFiles)

        $Skip = "CimClass", "CimInstanceProperties", "CimSystemProperties"

        $Detections = Get-MpThreatDetection -ErrorAction SilentlyContinue |
            Select-Object -Property *, @{
                Name       = "ResourceList";
                Expression = { @($_.Resources) -join "; " }
            } -ExcludeProperty ($Skip + "Resources")

        $Threats = Get-MpThreat -ErrorAction SilentlyContinue |
            Select-Object -Property *, @{
                Name       = "ResourceList";
                Expression = { @($_.Resources) -join "; " }
            } -ExcludeProperty ($Skip + "Resources")

        Write-OutputToCsv -Data $Detections -OutputFile $OutputFiles[0]
        Write-OutputToCsv -Data $Threats -OutputFile $OutputFiles[1]

        $Status = Get-MpComputerStatus -ErrorAction SilentlyContinue |
            Out-String -Width 4096
        Write-OutputToFile -Data $Status -OutputFile $OutputFiles[2]
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $Tasks = @(
        @{
            Action    = { param($Paths) Get-FirewallRules -OutputFile $Paths[0] }
            Message   = "08.01_Getting Device Firewall Configuration..."
            Files     = "08.01_firewall_rules.txt"
        }
        @{
            Action    = { param($Paths) Get-DefenderPreferences -OutputFile $Paths[0] }
            Message   = "08.02_Parsing Windows Defender Preferences..."
            Files     = "08.02_defender_preferences.txt"
        }
        @{
            Action    = { param($Paths) Copy-DefenderLogs -OutputFile $Paths[0] }
            Message   = "08.03_Copying Windows Defender Log Files..."
            Files     = "08.03_defender_log_files.txt"
        }
        @{
            Action    = { param($Paths) Get-DefenderDetections -OutputFiles $Paths }
            Message   = "08.04_Listing Windows Defender Detections..."
            Files     = "08.04a_defender_threat_detections.csv",
                        "08.04b_defender_threats.csv",
                        "08.04c_defender_status.txt"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $FirewallFolder

}
