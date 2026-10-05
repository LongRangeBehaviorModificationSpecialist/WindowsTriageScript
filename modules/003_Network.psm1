function Get-TriageNetworkData {
    [CmdletBinding()]
    param(
        [string]$NetworkFolder
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

    function Get-LocalIpInfoAsTxt {
        param(
            [string]$OutputFile = "$NetworkFolder\local_ip_info.txt"
        )
        $NetIpCommand = { Get-NetIPAddress | Select-Object -Property * }
        $NetIpData = &($NetIpCommand)
        Write-OutputToFile -Command $NetIpCommand -Data $NetIpData -OutputFile $OutputFile

        $IpConfigCommand = { & (Get-TriageBinary "ipconfig") /all }
        $IpConfigData = &($IpConfigCommand)
        Write-OutputToFile -Command $IpConfigCommand -Data $IpConfigData -OutputFile $OutputFile -Append
    }

    function Get-LocalIpInfoAsCsv {
        param(
            [string]$OutputFile = "$NetworkFolder\local_ip_info.csv"
        )
        $NetIpCommand = { Get-NetIPAddress | Select-Object -Property * }
        $NetIpData = &$NetIpCommand
        Write-OutputToCsv -Data $NetIpData -OutputFile $OutputFile
    }

    function Get-NetworkConfig {
        param(
            [string]$OutputFile = "$NetworkFolder\network_config.txt"
        )
        $Command = { Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq "True" } | Select-Object -Property * | Format-List }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }


    function Get-EstablishedConnections {
        param(
            [string]$OutputFile = "$NetworkFolder\netstat_established_connections.txt"
        )

        $Procs = @{}
        Get-CimInstance Win32_Process | ForEach-Object { $Procs[[int]$_.ProcessId] = $_ }

        $Rows = & (Get-TriageBinary "netstat") -nao | Select-String "ESTABLISHED" | ForEach-Object {
            $F = ($_.Line -split "\s+") | Where-Object { $_ }  # Proto, Local, Remote, State, PID
            $P = $Procs[[int]$F[4]]
            [pscustomobject]@{
                Local = $F[1]; Remote = $F[2]; PID = $F[4]
                ProcessName = $P.Name; Path = $P.ExecutablePath
                CommandLine = $P.CommandLine; Created = $P.CreationDate
            }
        }
        Write-OutputToCsv -Data $Rows -OutputFile $OutputFile
    }

    function Get-AllConnections {
        param(
            [string]$OutputFile = "$NetworkFolder\netstat_all_connections.txt"
        )
        $Command = { & (Get-TriageBinary "netstat") -nao }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-NetTcpConnections {
        param(
            [string]$OutputFile = "$NetworkFolder\net_tcp_connections.txt",
            [string]$CsvOutputFile = "$NetworkFolder\net_tcp_connections.csv"
        )
        $AllCommand = { Get-NetTCPConnection | Select-Object -Property * | Sort-Object LocalAddress -Desc }
        $AllData = &($AllCommand)
        Write-OutputToFile -Command $AllCommand -Data $AllData -OutputFile $OutputFile
        Write-OutputToCsv -Data $AllData -OutputFile $CsvOutputFile
    }

    function Get-DnsCache {
        param(
            [string]$OutputFile = "$NetworkFolder\dns_cache.txt"
        )
        $Command = { & (Get-TriageBinary "ipconfig") /displaydns }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-DnsCacheByRecordName {
        param(
            [string]$OutputFile = "$NetworkFolder\dns_cache_by_record_name.txt"
        )
        $Command = { & (Get-TriageBinary "ipconfig") /displaydns | Select-String "Record Name" | Sort-Object }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
    }

    function Get-NetworkShares {
        param(
            [string]$OutputFile = "$NetworkFolder\network_shares.csv"
        )
        Export-PerUserRegistry -EnumerateSubKeys -OutputFile $OutputFile -SubKey "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2"
    }

    function Get-SmbShareData {
        param(
            [string]$OutputFile = "$NetworkFolder\smb_shares.txt"
        )
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
            "network_shares.csv"
        )
        { Get-SmbShareData } = (
            "Parsing SMB Shares...",
            "smb_shares.txt"
        )
    }

    foreach ($Task in $NetworkWorkFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $Task.Key -FunctionMessage $Task.Value[0] -OutputFile $Task.Value[1]
    }
}
