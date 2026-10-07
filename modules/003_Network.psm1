function Get-TriageNetworkData {
    [CmdletBinding()]
    param(
        [string]$NetworkFolder
    )

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
                Local       = $F[1]
                Remote      = $F[2]
                PID         = $F[4]
                ProcessName = $P.Name
                Path        = $P.ExecutablePath
                CommandLine = $P.CommandLine
                Created     = $P.CreationDate
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

function Get-ArpCache {
        param(
            [string]$OutputFile = "$NetworkFolder\arp_neighbor_cache.csv"
        )
        $Data = Get-NetNeighbor -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, InterfaceIndex, AddressFamily, IPAddress, LinkLayerAddress, State
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-RoutingTable {
        param(
            [string]$OutputFile = "$NetworkFolder\routing_table.csv"
        )
        $Data = Get-NetRoute -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, InterfaceIndex, AddressFamily, DestinationPrefix, NextHop, RouteMetric, Protocol, Store
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-SmbActivity {
        $Skip = "CimClass", "CimInstanceProperties", "CimSystemProperties"
        if ((Get-Service -Name LanmanServer -ErrorAction SilentlyContinue).Status -eq "Running") {
            $Sessions = Get-SmbSession  -ErrorAction SilentlyContinue | Select-Object -Property * -ExcludeProperty $Skip
            $Opens    = Get-SmbOpenFile -ErrorAction SilentlyContinue | Select-Object -Property * -ExcludeProperty $Skip
        }
        else {
            $Sessions = $Opens = [pscustomobject]@{
                Note = "Server service (LanmanServer) not running; no inbound SMB sessions."
            }
        }
        Write-OutputToCsv -Data $Sessions -OutputFile "$NetworkFolder\smb_sessions.csv"
        Write-OutputToCsv -Data $Opens -OutputFile "$NetworkFolder\smb_open_files.csv"
        Write-OutputToCsv -Data (Get-SmbConnection -ErrorAction SilentlyContinue | Select-Object -Property * -ExcludeProperty $Skip) -OutputFile "$NetworkFolder\smb_client_connections.csv"
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $Tasks = @(
        @{
            Action  = { Get-LocalIpInfoAsTxt }
            Message = "Collecting local IP info as text..."
            Files   = "local_ip_info.txt"
        }
        @{
            Action  = {Get-LocalIPInfoAsCsv}
            Message = "Collecting local IP info to CSV..."
            Files   = "local_ip_info.csv"
        }
        @{
            Action  = { Get-NetworkConfig }
            Message = "Getting Network Configuration Information..."
            Files   = "network_config.txt"
        }
        @{
            Action  = { Get-EstablishedConnections }
            Message = "Getting Established Connections..."
            Files   = "netstat_established_connections.txt"
        }
        @{
            Action  = { Get-AllConnections }
            Message = "Getting Basic Internet Connection Information..."
            Files   = "netstat_all_connections.txt"
        }
        @{
            Action  = { Get-NetTcpConnections }
            Message = "Getting Network Connection Information..."
            Files   = "net_tcp_connections.txt", "net_tcp_connections.csv"
        }
        @{
            Action  = { Get-DnsCache }
            Message = "Parsing DNS Cache..."
            Files   = "dns_cache.txt"
        }
        @{
            Action  = { Get-DnsCacheByRecordName }
            Message = "Parsing DNS Cache by Record Name..."
            Files   = "dns_cache_by_record_name.txt"
        }
        @{
            Action  = { Get-NetworkShares }
            Message = "Parsing Network Shares..."
            Files   = "network_shares.csv"
        }
        @{
            Action  = { Get-SmbShareData }
            Message = "Parsing SMB Shares..."
            Files   = "smb_shares.txt"
        }
        @{
            Action = { Get-ArpCache }
            Message = "Getting ARP/neighbor cache..."
            Files = "arp_neighbor_cache.csv"
        }
        @{
            Action = { Get-RoutingTable }
            Message = "Getting routing table..."
            Files = "routing_table.csv"
        }
        @{
            Action = { Get-SmbActivity }
            Message = "Getting SMB sessions and open files..."
            Files = "smb_sessions.csv", "smb_open_files.csv", "smb_client_connections.csv"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $NetworkFolder
}
