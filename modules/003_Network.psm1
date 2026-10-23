function Get-TriageNetworkData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$NetworkFolder
    )
    begin {
        function Get-IpConfig {
            param(
                [string]$TxtFile = (Join-Path -Path $NetworkFolder -ChildPath "ip_config_all.txt")
            )
            $Data = & (Get-TriageBinary "ipconfig") /all
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-LocalIpInfoAsCsv {
            param(
                [string]$CsvFile = (Join-Path -Path $NetworkFolder -ChildPath "local_ip_info.csv")
            )
            $Data = Get-NetIPAddress | Select-Object -Property *
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-NetworkConfig {
            param(
                [string]$TxtFile = (Join-Path -Path $NetworkFolder -ChildPath "network_config.txt")
            )
            $Data = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration |
                Where-Object { $_.IPEnabled -eq "True" } |
                Select-Object -Property * | Format-List
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-EstablishedConnections {
            param(
                [string]$CsvFile = (Join-Path -Path $NetworkFolder -ChildPath "established_connections.csv")
            )
            $Procs = @{}
            Get-CimInstance Win32_Process | ForEach-Object { $Procs[[int]$_.ProcessId] = $_ }
            $Data = & (Get-TriageBinary "netstat") -nao | Select-String "ESTABLISHED" | ForEach-Object {
                $F = ($_.Line -split "\s+") | Where-Object { $_ }  # Proto, Local, Remote, State, PID
                $P = $Procs[[int]$F[4]]
                [PSCustomObject]@{
                    Local       = $F[1]
                    Remote      = $F[2]
                    PID         = $F[4]
                    ProcessName = $P.Name
                    Path        = $P.ExecutablePath
                    CommandLine = $P.CommandLine
                    Created     = $P.CreationDate
                }
            }
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-AllConnections {
            param(
                [string]$CsvFile = (Join-Path -Path $NetworkFolder -ChildPath "netstat_all_connections.csv")
            )
            $Data = & (Get-TriageBinary "netstat") -nao 2>&1 | ForEach-Object { "$_" }
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-NetTcpConnections {
            param(
                [string]$CsvFile = (Join-Path -Path $NetworkFolder -ChildPath "net_tcp_connections.csv")
            )
            $Data = Get-NetTCPConnection | Select-Object -Property * | Sort-Object LocalAddress -Desc
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-DnsCache {
            param(
                [string]$TxtFile = (Join-Path -Path $NetworkFolder -ChildPath "dns_cache.txt")
            )
            $Data = & (Get-TriageBinary "ipconfig") /displaydns
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-DnsCacheByRecordName {
            param(
                [string]$TxtFile = (Join-Path -Path $NetworkFolder -ChildPath "dns_cache_by_record_name.txt")
            )
            $Data = & (Get-TriageBinary "ipconfig") /displaydns | Select-String "Record Name" | Sort-Object
            Write-OutputToFile -Data $Data -OutputFile $TxtFile
        }

        function Get-NetworkShares {
            param(
                [string]$CsvFile = (Join-Path -Path $NetworkFolder -ChildPath "network_shares.csv")
            )
            Export-PerUserRegistry -EnumerateSubKeys -OutputFile $CsvFile -SubKey "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2"
        }

        function Get-SmbShareData {
            param(
                [string]$CsvFile = (Join-Path -Path $NetworkFolder -ChildPath "smb_shares.csv")
            )
            $Data = Get-SmbShare | Select-Object -Property *
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-ArpCache {
            param(
                [string]$CsvFile = (Join-Path -Path $NetworkFolder -ChildPath "arp_neighbor_cache.csv")
            )
            $Data = Get-NetNeighbor -ErrorAction SilentlyContinue |
                Select-Object InterfaceAlias, InterfaceIndex, AddressFamily, IPAddress, LinkLayerAddress, State, Name, Status
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-RoutingTable {
            param(
                [string]$CsvFile = (Join-Path -Path $NetworkFolder -ChildPath "routing_table.csv")
            )
            $Data = Get-NetRoute -ErrorAction SilentlyContinue |
                Select-Object InterfaceAlias, InterfaceIndex, AddressFamily, DestinationPrefix, NextHop, RouteMetric, Protocol, Store
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-SmbActivity {
            param(
                [string]$SessionCsvFile = (Join-Path -Path $NetworkFolder -ChildPath "smb_sessions.csv"),
                [string]$OpensCsvFile = (Join-Path -Path $NetworkFolder -ChildPath "smb_open_files.csv"),
                [string]$ConnectionsCsvFile = (Join-Path -Path $NetworkFolder -ChildPath "smb_client_connections.csv")
            )
            $Skip = "CimClass", "CimInstanceProperties", "CimSystemProperties"
            if ((Get-Service -Name LanmanServer -ErrorAction SilentlyContinue).Status -eq "Running") {
                $Sessions = Get-SmbSession -ErrorAction SilentlyContinue | Select-Object -Property * -ExcludeProperty $Skip
                $Opens = Get-SmbOpenFile -ErrorAction SilentlyContinue | Select-Object -Property * -ExcludeProperty $Skip
            }
            else {
                $Sessions = $Opens = [PSCustomObject]@{
                    Note = "Server service (LanmanServer) not running; no inbound SMB sessions."
                }
            }
            Write-OutputToCsv -Data $Sessions -OutputFile $SessionCsvFile
            Write-OutputToCsv -Data $Opens -OutputFile $OpensCsvFile
            Write-OutputToCsv -Data (Get-SmbConnection -ErrorAction SilentlyContinue |
                Select-Object -Property * -ExcludeProperty $Skip) -OutputFile $ConnectionsCsvFile
        }
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------
    process {
        $Tasks = @(
            @{
                Action  = { Get-IpConfig }
                Message = "Gathering All IpConfig Data..."
                Files   = "ip_config_all.txt"
            }
            @{
                Action  = { Get-LocalIPInfoAsCsv }
                Message = "Collecting Local IP Info (CSV)..."
                Files   = "local_ip_info.csv"
            }
            @{
                Action  = { Get-NetworkConfig }
                Message = "Getting Network Configuration Information..."
                Files   = "network_config.txt"
            }
            @{
                Action  = { Get-EstablishedConnections }
                Message = "Gathering Established Connections..."
                Files   = "established_connections.csv"
            }
            @{
                Action  = { Get-AllConnections }
                Message = "Getting Basic Internet Connection Information..."
                Files   = "netstat_all_connections.csv"
            }
            @{
                Action  = { Get-NetTcpConnections }
                Message = "Getting Network Connection Information..."
                Files   = "net_tcp_connections.csv"
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
                Files   = "smb_shares.csv"
            }
            @{
                Action  = { Get-ArpCache }
                Message = "Getting ARP/neighbor cache..."
                Files   = "arp_neighbor_cache.csv"
            }
            @{
                Action  = { Get-RoutingTable }
                Message = "Getting routing table..."
                Files   = "routing_table.csv"
            }
            @{
                Action  = { Get-SmbActivity }
                Message = "Getting SMB sessions and open files..."
                Files   = "smb_sessions.csv", "smb_open_files.csv", "smb_client_connections.csv"
            }
        )

        Invoke-TriageTaskList -Tasks $Tasks -Folder $NetworkFolder
    }
}
