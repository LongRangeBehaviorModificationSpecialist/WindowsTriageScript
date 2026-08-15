function Get-TriageNetworkData {
    [CmdletBinding()]

    param([string]$NetworkFolder)

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

    function Get-LocalIpInfoAsTxt {
        param([string]$OutputFile     = "$NetworkFolder\local_ip_info.txt")
        $NetIpCommand = { Get-NetIPAddress | Select-Object -Property * }
        $NetIpData = &$NetIpCommand
        Write-OutputToFile -Command $NetIpCommand -Data $NetIpData -OutputFile $OutputFile

        $IpConfigCommand = { ipconfig /all }
        $IpConfigData = &$IpConfigCommand
        Write-OutputToFile -Command $IpConfigCommand -Data $IpConfigData -OutputFile $OutputFile -Append
    }

    function Get-LocalIpInfoAsCsv {
        param([string]$OutputFile  = "$NetworkFolder\local_ip_info.csv")
        $NetIpCommand = { Get-NetIPAddress | Select-Object -Property * }
        $NetIpData = &$NetIpCommand
        Write-OutputToCsv -Data $NetIpData -OutputFile $CsvOutputFile
    }

    function Get-NetworkConfig {
        param([string]$OutputFile = "$NetworkFolder\network_config.txt")
        $Command = { Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq "True" } | Select-Object -Property * | Format-List }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-EstablishedConnections {
        param([string]$OutputFile = "$NetworkFolder\netstat_established_connections.txt")
        $Command = netstat -nao | Select-String "ESTA"

        foreach ($Element in $Command) {
            $Data = $Element -split " " | Where-Object { $_ -ne "" }
            New-Object -TypeName PSObject -Property @{
                "Local IP : Port#"              = $Data[1];
                "Remote IP : Port#"             = $Data[2];
                "Process ID"                    = $Data[4];
                "Process Name"                  = ((Get-Process | Where-Object { $_.ID -eq $Data[4] })).Name
                "Process File Path"             = ((Get-Process | Where-Object { $_.ID -eq $Data[4] })).Path
                "Process Start Time"            = ((Get-Process | Where-Object { $_.ID -eq $Data[4] })).StartTime
                "Associated DLLs and File Path" = ((Get-Process | Where-Object { $_.ID -eq $Data[4] })).Modules |
                    Select-Object @{ N = "Module"; E = { $_.FileName -join "; " } } |
                    Out-String
            } | Out-File -Append -FilePath $OutputFile
        }
    }

    function Get-AllConnections {
        param([string]$OutputFile = "$NetworkFolder\netstat_all_connections.txt")
        $Command = { netstat -nao }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-NetTcpConnections {
        param(
            [string]$OutputFile    = "$NetworkFolder\net_tcp_connections.txt",
            [string]$CsvOutputFile = "$NetworkFolder\net_tcp_connections.csv"
        )
        $AllCommand = { Get-NetTCPConnection | Select-Object -Property * | Sort-Object LocalAddress -Desc }
        $AllData = &($AllCommand)
        Write-OutputToFile -Command $AllCommand -Data $AllData -OutputFile $OutputFile
        Write-OutputToCsv -Data $AllData -OutputFile $CsvOutputFile
    }

    function Get-DnsCache {
        param([string]$OutputFile = "$NetworkFolder\dns_cache.txt")
        $Command = { ipconfig /displaydns }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-DnsCacheByRecordName {
        param([string]$OutputFile = "$NetworkFolder\dns_cache_by_record_name.txt")
        $Command = { ipconfig /displaydns | Select-String "Record Name" | Sort-Object }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-NetworkShares {
        param([string]$OutputFile = "$NetworkFolder\network_shares.txt")
        $Command = { Get-ChildItem -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2" | Select-Object * -ExcludeProperty PS* }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-SmbShareData {
        param([string]$OutputFile = "$NetworkFolder\smb_shares.txt")
        $Command =  { Get-SmbShare | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $NetworkWorkFlow = [ordered]@{
        { Get-LocalIpInfoAsTxt } = (
            "Collecting local IP info as text...",
            "local_ip_info.txt"
        )
        {Get-LocalIPInfoAsCsv} = (
            "Collecting local IP info to CSV...",
            "local_ip_info.csv"
        )
        { Get-NetworkConfig } = (
            "Getting Network Configuration Information...",
            "network_config.txt"
        )
        { Get-EstablishedConnections } = (
            "Getting Established Connections...",
            "netstat_established_connections.txt"
        )
        { Get-AllConnections } = (
            "Getting Basic Internet Connection Information...",
            "netstat_all_connections.txt"
        )
        { Get-NetTcpConnections } = (
            "Getting Network Connection Information...",
            "[net_tcp_connections.txt, net_tcp_connections.csv]"
        )
        { Get-DnsCache } = (
            "Parsing DNS Cache...",
            "dns_cache.txt"
        )
        { Get-DnsCacheByRecordName } = (
            "Parsing DNS Cache by Record Name...",
            "dns_cache_by_record_name.txt"
        )
        { Get-NetworkShares } = (
            "Parsing Network Shares...",
            "network_shares.txt"
        )
        { Get-SmbShareData } = (
            "Parsing SMB Shares...",
            "smb_shares.txt"
        )
    }

    foreach ($Task in $NetworkWorkFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $Task.key -FunctionMessage $Task.value[0] -OutputFile $Task.value[1]
    }
}
