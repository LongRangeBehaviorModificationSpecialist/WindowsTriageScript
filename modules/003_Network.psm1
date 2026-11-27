function Get-TriageNetworkData {
    <#
    .SYNOPSIS
    Collects network configuration, connections, caches, shares, and SMB
    activity ( module 003_Network ).

    .DESCRIPTION
    Runs a series of read-only collection tasks and writes the results to
    the module folder:

        03.01_ip_config_all.txt
            'ipconfig /all'
        03.02_local_ip_info.csv
            IP addresses ( 'Get-NetIPAddress' )
        03.03_network_config.txt
            Enabled adapters ( 'Win32_NetworkAdapterConfiguration' )
        03.04_netstat_all_connections.csv
            All connections from 'netstat -nao'
        03.05_net_tcp_connections.csv
            TCP connections ( 'Get-NetTCPConnection' )
        03.06_dns_cache.txt
            DNS client cache ( 'ipconfig /displaydns' )
        03.07_dns_cache_by_record.txt
            The DNS cache arranged by record name
        03.08_network_shares.csv
            Mapped drives and network locations remembered in each user's
            registry ( Explorer\MountPoints2 )
        03.09_smb_shares.csv
            Shares this computer offers ( 'Get-SmbShare' )
        03.10_arp_neighbor_cache.csv
            ARP and neighbor cache ( 'Get-NetNeighbor' )
        03.11_routing_table.csv
            Routing table ( 'Get-NetRoute' )
        03.12a_smb_sessions.csv,
        03.12b_smb_open_files.csv, and
        03.12c_smb_client_connections.csv
            Inbound SMB sessions and open files, and computer's outbound
            SMB connections
        03.13_wlan_profiles.txt
            Wireless network profiles list ( 'netsh wlan show profiles' &
            'netsh wlan showinterfaces' )

    The inbound SMB sessions and open files ( 03.12a and 03.12b ) are
    collected only if the Server service ( LanmanServer ) is running;
    otherwise those two files contain a note indicating that it is
    not running.

    Outbound connections are always collected.

    .PARAMETER NetworkFolder
    Path of the folder where this module writes its files.

    'Invoke-DfirTriageScan' creates it as '<ResultsFolder>\003_Network'.

    .INPUTS
    None.

    .OUTPUTS
    None.  Results are written to files in NetworkFolder, and progress
    is written to the screen and the log.

    .EXAMPLE
    Get-TriageNetworkData `
        -NetworkFolder 'E:\Triage\Case-2026-12345\003_Network'

    Writes the 03.xx files into that folder.

    .EXAMPLE
    Invoke-DfirTriageScan -ResultsFolder $Folder -Operator 'SA John Doe' `
        -CaseNumber '2026-12345' -Modules '003_Network'

    The usual way this module runs, on its own.

    .NOTES
    Requires an elevated session. The 'ipconfig' and 'netstat' copies from
    '\bin' are found with 'Get-TriageBinary', which only works after
    'Initialize-TriageSystemTools' has run, so call this function through
    'Invoke-DfirTriageScan'.

    Task 03.09 reads the user registry hives that 'Invoke-DfirTriageScan'
    mounts, so it needs those hives ( in '$global:TriageUserHives' ) to be
    available.

    Connection, DNS, and ARP data are volatile and change from moment to
    moment; the timestamp of each file shows when it was captured.

    Process ownership in 03.04 reflects the moment 'netstat' ran.

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


    # 03.01
    function Get-IpConfig {
        param([string]$OutputFile)

        $Data = & (Get-TriageBinary "ipconfig") /all
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 03.02
    function Get-LocalIpInfoAsCsv {
        param([string]$OutputFile)

        $Data = Get-NetIPAddress | Select-Object -Property *
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # 03.03
    function Get-NetworkConfig {
        param([string]$OutputFile)

        $Data = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration |
            Where-Object { $_.IPEnabled -eq "True" } |
            Select-Object -Property * |
            Format-List
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 03.04
    function Get-AllConnections {
        param([string]$OutputFile)

        $Data = & (Get-TriageBinary "netstat") -nao 2>&1 |
        Where-Object { $_ -match '^\s*(TCP|UDP)\b' } |
        ForEach-Object {
            $Parts = ($_ -replace '^\s+', '') -split '\s+'
            $IsTcp = $Parts[0] -eq "TCP"
            [PSCustomObject]@{
                Protocol      = $Parts[0]
                LocalAddress  = ($Parts[1] -replace ':\d+$', '')
                LocalPort     = [int]($Parts[1] -replace '^.*:', '')
                RemoteAddress = if ($IsTcp) { ($Parts[2] -replace ':\d+$', '') } else { '*' }
                RemotePort    = if ($IsTcp) { [int]($Parts[2] -replace '^.*:', '') } else { 0 }
                State         = if ($IsTcp) { $Parts[3] } else { '*' }
                OwningPid     = [int]($Parts[-1])
            }
        }
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # 03.05
    function Get-NetTcpConnections {
        param([string]$OutputFile)

        $Data = Get-NetTCPConnection |
            Select-Object -Property * |
            Sort-Object LocalAddress -Descending
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # 03.06
    function Get-DnsCache {
        param([string]$OutputFile)

        $Data = & (Get-TriageBinary "ipconfig") /displaydns
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 03.07
    function Get-DnsCacheByRecordName {
        param([string]$OutputFile)

        $Data = & (Get-TriageBinary "ipconfig") /displaydns |
            Select-String "Record Name" |
            Sort-Object
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }


    # 03.08
    function Get-NetworkShares {
        param(
            [string]$OutputFile,
            [string]$SubKey =
                "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2"
        )

        Export-PerUserRegistry -EnumerateSubKeys -OutputFile $OutputFile -SubKey $SubKey
    }


    # 03.09
    function Get-SmbShareData {
        param([string]$OutputFile)

        $Data = Get-SmbShare | Select-Object -Property *
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # 03.10
    function Get-ArpCache {
        param([string]$OutputFile)

        $Data = Get-NetNeighbor -ErrorAction SilentlyContinue |
            Select-Object InterfaceAlias, InterfaceIndex, AddressFamily,
            IPAddress, LinkLayerAddress, State, Name, Status
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # 03.11
    function Get-RoutingTable {
        param([string]$OutputFile)

        $Data = Get-NetRoute -ErrorAction SilentlyContinue |
            Select-Object -Property InterfaceAlias, InterfaceIndex, `
            AddressFamily, State, DestinationPrefix, NextHop, RouteMetric, `
            Protocol, Store
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # 03.12
    function Get-SmbActivity {
        param([string[]]$OutputFiles)

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

        Write-OutputToCsv -Data $Sessions -OutputFile $OutputFiles[0]
        Write-OutputToCsv -Data $Opens -OutputFile $OutputFiles[1]
        Write-OutputToCsv -Data $Connections -OutputFile $OutputFiles[2]
    }


    # 03.13
    function Get-WlanProfiles {
        param([string]$OutputFile)

        $Netsh = Get-TriageBinary "netsh"
        $Data  = @(& $Netsh wlan show profiles key=clear) + @(& $Netsh wlan show interfaces)
        Write-OutputToFile -Data $Data -OutputFile $OutputFile
    }

    # ------------------------------------------------------------------
    # Task list.
    #
    # Filenames are declared here, exactly once. Each action receives an
    # array of resolved full paths ($Paths) and forwards them to the
    # collector functions.
    # ------------------------------------------------------------------

    $Tasks = @(
        @{
            Action    = { param($Paths) Get-IpConfig -OutputFile $Paths[0] }
            Message   = "03.01_Gathering All IpConfig Data..."
            Files     = "03.01_ip_config_all.txt"
        }
        @{
            Action    = { param($Paths) Get-LocalIpInfoAsCsv -OutputFile $Paths[0] }
            Message   = "03.02_Collecting Local IP Info (CSV)..."
            Files     = "03.02_local_ip_info.csv"
        }
        @{
            Action    = { param($Paths) Get-NetworkConfig -OutputFile $Paths[0] }
            Message   = "03.03_Getting Network Configuration Information..."
            Files     = "03.03_network_config.txt"
        }
        @{
            Action    = { param($Paths) Get-AllConnections -OutputFile $Paths[0] }
            Message   = "03.04_Getting Basic Internet Connection Information..."
            Files     = "03.04_netstat_all_connections.csv"
        }
        @{
            Action    = { param($Paths) Get-NetTcpConnections -OutputFile $Paths[0] }
            Message   = "03.05_Getting Network Connection Information..."
            Files     = "03.05_net_tcp_connections.csv"
        }
        @{
            Action    = { param($Paths) Get-DnsCache -OutputFile $Paths[0] }
            Message   = "03.06_Parsing DNS Cache..."
            Files     = "03.06_dns_cache.txt"
        }
        @{
            Action    = { param($Paths) Get-DnsCacheByRecordName -OutputFile $Paths[0] }
            Message   = "03.07_Parsing DNS Cache by Record Name..."
            Files     = "03.07_dns_cache_by_record.txt"
        }
        @{
            Action    = { param($Paths) Get-NetworkShares -OutputFile $Paths[0] }
            Message   = "03.08_Parsing Network Shares..."
            Files     = "03.08_network_shares.csv"
        }
        @{
            Action    = { param($Paths) Get-SmbShareData -OutputFile $Paths[0] }
            Message   = "03.09_Parsing SMB Shares..."
            Files     = "03.09_smb_shares.csv"
        }
        @{
            Action    = { param($Paths) Get-ArpCache -OutputFile $Paths[0] }
            Message   = "03.10_Getting ARP/neighbor cache..."
            Files     = "03.10_arp_neighbor_cache.csv"
        }
        @{
            Action    = { param($Paths) Get-RoutingTable -OutputFile $Paths[0] }
            Message   = "03.11_Getting routing table..."
            Files     = "03.11_routing_table.csv"
        }
        @{
            Action    = { param($Paths) Get-SmbActivity -OutputFiles $Paths }
            Message   = "03.12_Getting SMB sessions and open files..."
            Files     = "03.12a_smb_sessions.csv",
                        "03.12b_smb_open_files.csv",
                        "03.12c_smb_client_connections.csv"
        }
        @{
            Action    = { param($Paths) Get-WlanProfiles -OutputFile $Paths[0] }
            Message   = "03.13_Getting saved Wi-Fi profiles..."
            Files     = "03.13_wlan_profiles.txt"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $NetworkFolder

}
