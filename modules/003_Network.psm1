function Get-TriageNetworkData {
    [CmdletBinding()]
    param(
        [string]$network_folder
    )


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$action,
            [string]$function_msg,
            [string]$output_file
        )
        try {
            Show-MessageAndWriteLogEntry -Msg $function_msg -Level INFO
            & $action
            Show-MessageAndWriteLogEntry -File $output_file -Level SUCCESS
        }
        catch {
            $error_msg = "Execution failed during `"$($MyInvocation.MyCommand.Name)`". Error: $($_.Exception.Message)"
            Show-MessageAndWriteLogEntry -Msg $error_msg -Level ERROR
        }
    }


    function Get-LocalIpInfo {
        param(
            [string]$output_file     = "$network_folder\local_ip_info.txt",
            [string]$csv_output_file = "$network_folder\local_ip_info.csv"
        )
        $net_ip_command =   { Get-NetIPAddress |
                                Select-Object -Property *
                            }
        $net_ip_data = &$net_ip_command
        Write-OutputToFile -Command $net_ip_command -Data $net_ip_data -OutputFile $output_file
        Write-OutputToCsv -Data $net_ip_data -OutputFile $csv_output_file

        $ip_config_command = { ipconfig /all }
        $ip_config_data = &$ip_config_command
        Write-OutputToFile -Command $ip_config_command -Data $ip_config_data -OutputFile $output_file -Append
    }

    function Get-NetworkConfig {
        param(
            [string]$output_file = "$network_folder\network_config.txt"
        )
        $command =  { Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration |
                        Where-Object { $_.IPEnabled -eq "True" } |
                        Select-Object -Property * |
                        Format-List
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-EstablishedConnections {
        param(
            [string]$output_file = "$network_folder\netstat_established_connections.txt"
        )
        $command = netstat -nao | Select-String "ESTA"

        foreach ($element in $command) {
            $data = $element -split " " | Where-Object { $_ -ne "" }
            New-Object -TypeName PSObject -Property @{
                "Local IP : Port#"              = $data[1];
                "Remote IP : Port#"             = $data[2];
                "Process ID"                    = $data[4];
                "Process Name"                  = ((Get-Process | Where-Object { $_.ID -eq $data[4] })).Name
                "Process File Path"             = ((Get-Process | Where-Object { $_.ID -eq $data[4] })).Path
                "Process Start Time"            = ((Get-Process | Where-Object { $_.ID -eq $data[4] })).StartTime
                "Associated DLLs and File Path" = ((Get-Process | Where-Object { $_.ID -eq $data[4] })).Modules |
                    Select-Object @{ N = "Module"; E = { $_.FileName -join "; " } } |
                    Out-String
            } | Out-File -Append -FilePath $output_file
        }
    }


    function Get-AllConnections {
        param(
            [string]$output_file = "$network_folder\netstat_all_connections.txt"
        )
        $command =  { netstat -nao }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-NetTcpConnections {
        param(
            [string]$output_file     = "$network_folder\net_tcp_connections.txt",
            [string]$csv_output_file = "$network_folder\net_tcp_connections.csv"
        )
        $all_command =   { Get-NetTCPConnection |
                            Select-Object -Property * |
                            Sort-Object LocalAddress -Desc
                        }
        $all_data = &$all_command
        Write-OutputToFile -Command $all_command -Data $all_data -OutputFile $output_file
        Write-OutputToCsv -Data $all_data -OutputFile $csv_output_file
    }


    function Get-DnsCache {
        param(
            [string]$output_file = "$network_folder\dns_cache.txt"
        )
        $command = { ipconfig /displaydns }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-DnsCacheByRecordName {
        param(
            [string]$output_file = "$network_folder\dns_cache_by_record_name.txt"
        )
        $command =  { ipconfig /displaydns |
                        Select-String "Record Name" |
                        Sort-Object
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-NetworkShares {
        param(
            [string]$output_file = "$network_folder\network_shares.txt"
        )
        $command =  { Get-ChildItem -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2" |
                        Select-Object * -ExcludeProperty PS*
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    function Get-SmbShareData {
        param(
            [string]$output_file = "$network_folder\smb_shares.txt"
        )
        $command =  { Get-SmbShare |
                        Select-Object -Property *
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $network_work_flow = [ordered]@{
        { Get-LocalIpInfo } = (
            "Collecting local IP info...",
            "[local_ip_info.txt, local_ip_info.csv]"
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

    foreach ($task in $network_work_flow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
