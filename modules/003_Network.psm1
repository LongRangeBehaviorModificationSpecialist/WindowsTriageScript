function Get-TriageNetworkData {
    <#
    .SYNOPSIS
        Collects network configuration, connections, caches, shares, and SMB
        activity (module 003_Network).

    .DESCRIPTION
        Runs a series of read-only collection tasks and writes the results to
        the module folder:

            03.01_ip_config_all.txt
                `ipconfig /all`.
            03.02_local_ip_info.csv
                IP addresses (`Get-NetIPAddress`).
            03.03_network_config.txt
                Enabled adapters (`Win32_NetworkAdapterConfiguration`).
            03.04_netstat_all_connections.csv
                All connections from `netstat -nao`.
            03.05_net_tcp_connections.csv
                TCP connections (`Get-NetTCPConnection`).
            03.06_dns_cache.txt
                DNS client cache (`ipconfig /displaydns`).
            03.07_dns_cache_by_record.txt
                The DNS cache arranged by record name.
            03.08_network_shares.csv
                Mapped drives and network locations remembered in each user's
                registry (Explorer\MountPoints2).
            03.09_smb_shares.csv
                Shares this computer offers (`Get-SmbShare`).
            03.10_arp_neighbor_cache.csv
                ARP and neighbor cache (`Get-NetNeighbor`).
            03.11_routing_table.csv
                Routing table (`Get-NetRoute`).
            03.12a_smb_sessions.csv,
            03.12b_smb_open_files.csv,
            03.12c_smb_client_connections.csv
                Inbound SMB sessions and open files, and computer's outbound
                SMB connections.
            03.13_wlan_profiles.txt
                Wireless network profiles list (`netsh wlan show profiles` &
                `netsh wlan showinterfaces`)

        The inbound SMB sessions and open files (03.13a and 03.13b) are
        collected only if the Server service (LanmanServer) is running;
        otherwise those two files contain a note indicating that it is
        not running.

        Outbound connections are always collected.

    .PARAMETER NetworkFolder
        Path of the folder where this module writes its files.

        `Invoke-DfirTriageScan` creates it as `<ResultsFolder>\003_Network`.

    .INPUTS
        None.

        This function does not accept pipeline input.

    .OUTPUTS
        None.

        Results are written to files in NetworkFolder, and progress is
        written to the screen and the log.

    .EXAMPLE
        Get-TriageNetworkData `
            -NetworkFolder "E:\Triage\Case-2026-0142\003_Network"

        Writes the 03.xx files into that folder.

    .EXAMPLE
        Invoke-DfirTriageScan -ResultsFolder $Folder -Operator "J. Smith" `
            -CaseNumber "2026-0142" -Modules "003_Network"

        The usual way this module runs, on its own.

    .NOTES
        Requires an elevated session. The `ipconfig` and `netstat` copies from
        `\bin` are found with `Get-TriageBinary`, which only works after
        `Initialize-TriageSystemTools` has run, so call this function through
        `Invoke-DfirTriageScan`.

        Task 03.09 reads the user registry hives that `Invoke-DfirTriageScan`
        mounts, so it needs those hives (in `$global:TriageUserHives`) to be
        available.

        Connection, DNS, and ARP data are volatile and change from moment to
        moment; the timestamp of each file shows when it was captured.

        Process ownership in 03.04 reflects the moment `netstat` ran.

        Each task is isolated: if one fails, the error is logged and the next
        task still runs.

        A task whose output file is missing or empty is also reported as an
        error.

    .LINK
        Invoke-DfirTriageScan

    .LINK
        Invoke-TriageTaskList
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$NetworkFolder
    )

    function Get-IpConfig {
        param(
            [string]$TxtFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.01_ip_config_all.txt"
            )
        )
        $Data = & (Get-TriageBinary "ipconfig") /all
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-LocalIpInfoAsCsv {
        param(
            [string]$CsvFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.02_local_ip_info.csv"
            )
        )
        $Data = Get-NetIPAddress | Select-Object -Property *
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile
    }


    function Get-NetworkConfig {
        param(
            [string]$TxtFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.03_network_config.txt"
            )
        )
        $Data = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration |
            Where-Object { $_.IPEnabled -eq "True" } |
            Select-Object -Property * |
            Format-List
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-AllConnections {
        param(
            [string]$CsvFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.04_netstat_all_connections.csv"
            )
        )
        $Data = & (Get-TriageBinary "netstat") -nao 2>&1 |
            ForEach-Object { "$_" }
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile
    }


    function Get-NetTcpConnections {
        param(
            [string]$CsvFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.05_net_tcp_connections.csv"
            )
        )
        $Data = Get-NetTCPConnection |
            Select-Object -Property * |
            Sort-Object LocalAddress -Desc
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile
    }


    function Get-DnsCache {
        param(
            [string]$TxtFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.06_dns_cache.txt"
            )
        )
        $Data = & (Get-TriageBinary "ipconfig") /displaydns
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-DnsCacheByRecordName {
        param(
            [string]$TxtFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.07_dns_cache_by_record.txt"
            )
        )
        $Data = & (Get-TriageBinary "ipconfig") /displaydns |
            Select-String "Record Name" |
            Sort-Object
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-NetworkShares {
        param(
            [string]$CsvFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.08_network_shares.csv"
            ),
            [string]$SubKey = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2"
        )
        Export-PerUserRegistry -EnumerateSubKeys -OutputFile $CsvFile -SubKey $SubKey
    }


    function Get-SmbShareData {
        param(
            [string]$CsvFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.09_smb_shares.csv"
            )
        )
        $Data = Get-SmbShare | Select-Object -Property *
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile
    }


    function Get-ArpCache {
        param(
            [string]$CsvFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.10_arp_neighbor_cache.csv"
            )
        )
        $Data = Get-NetNeighbor -ErrorAction SilentlyContinue |
            Select-Object InterfaceAlias, InterfaceIndex, AddressFamily, `
            IPAddress, LinkLayerAddress, State, Name, Status
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile
    }


    function Get-RoutingTable {
        param(
            [string]$CsvFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.11_routing_table.csv"
            )
        )
        $Data = Get-NetRoute -ErrorAction SilentlyContinue |
            Select-Object -Property InterfaceAlias, InterfaceIndex, `
            AddressFamily, State, DestinationPrefix, NextHop, RouteMetric, `
            Protocol, Store
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile
    }


    function Get-SmbActivity {
        param(
            [string]$SessionCsvFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.12a_smb_sessions.csv"
            ),
            [string]$OpensCsvFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.12b_smb_open_files.csv"
            ),
            [string]$ConnectionsCsvFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.12c_smb_client_connections.csv"
            )
        )
        $Skip = "CimClass", "CimInstanceProperties", "CimSystemProperties"
        if ((Get-Service -Name LanmanServer -ErrorAction SilentlyContinue).Status -eq "Running") {
            $Sessions = Get-SmbSession -ErrorAction SilentlyContinue |
                Select-Object -Property * -ExcludeProperty $Skip
            $Opens = Get-SmbOpenFile -ErrorAction SilentlyContinue |
                Select-Object -Property * -ExcludeProperty $Skip
        }
        else {
            $Sessions = $Opens = [PSCustomObject]@{
                Note = "Server service (LanmanServer) not running; no inbound SMB sessions."
            }
        }
        $Connections = Get-SmbConnection -ErrorAction SilentlyContinue |
            Select-Object -Property * -ExcludeProperty $Skip

        Write-OutputToCsv -Data $Sessions -OutputFile $SessionCsvFile
        Write-OutputToCsv -Data $Opens -OutputFile $OpensCsvFile
        Write-OutputToCsv -Data $Connections -OutputFile $ConnectionsCsvFile
    }


    function Get-WlanProfiles {
        param(
            [string]$TxtFile = (
                Join-Path -Path $NetworkFolder -ChildPath "03.13_wlan_profiles.txt"
            )
        )
        $Netsh = & (Get-TriageBinary "netsh")
        $Data  = @(& $Netsh wlan show profiles) + @(& $Netsh wlan show interfaces)  # key=clear
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $Tasks = @(
        @{
            Action    = { Get-IpConfig }
            Message   = "03.01_Gathering All IpConfig Data..."
            Files     = "03.01_ip_config_all.txt"
        }
        @{
            Action    = { Get-LocalIPInfoAsCsv }
            Message   = "03.02_Collecting Local IP Info (CSV)..."
            Files     = "03.02_local_ip_info.csv"
        }
        @{
            Action    = { Get-NetworkConfig }
            Message   = "03.03_Getting Network Configuration Information..."
            Files     = "03.03_network_config.txt"
        }
        @{
            Action    = { Get-AllConnections }
            Message   = "03.04_Getting Basic Internet Connection Information..."
            Files     = "03.04_netstat_all_connections.csv"
        }
        @{
            Action    = { Get-NetTcpConnections }
            Message   = "03.05_Getting Network Connection Information..."
            Files     = "03.05_net_tcp_connections.csv"
        }
        @{
            Action    = { Get-DnsCache }
            Message   = "03.06_Parsing DNS Cache..."
            Files     = "03.06_dns_cache.txt"
        }
        @{
            Action    = { Get-DnsCacheByRecordName }
            Message   = "03.07_Parsing DNS Cache by Record Name..."
            Files     = "03.07_dns_cache_by_record.txt"
        }
        @{
            Action    = { Get-NetworkShares }
            Message   = "03.08_Parsing Network Shares..."
            Files     = "03.08_network_shares.csv"
        }
        @{
            Action    = { Get-SmbShareData }
            Message   = "03.09_Parsing SMB Shares..."
            Files     = "03.09_smb_shares.csv"
        }
        @{
            Action    = { Get-ArpCache }
            Message   = "03.10_Getting ARP/neighbor cache..."
            Files     = "03.10_arp_neighbor_cache.csv"
        }
        @{
            Action    = { Get-RoutingTable }
            Message   = "03.11_Getting routing table..."
            Files     = "03.11_routing_table.csv"
        }
        @{
            Action    = { Get-SmbActivity }
            Message   = "03.12_Getting SMB sessions and open files..."
            Files     = "03.12a_smb_sessions.csv",
                        "03.12b_smb_open_files.csv",
                        "03.12c_smb_client_connections.csv"
        }
        @{
            Action    = { Get-WlanProfiles }
            Message   = "03.13_Getting saved Wi-Fi profiles..."
            Files     = "03.13_wlan_profiles.txt"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $NetworkFolder

}
