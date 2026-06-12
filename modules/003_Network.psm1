function Get-TriageNetworkData {
    [CmdletBinding()]
    param(
        [string]$networkFolder
    )


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$action,
            [string]$functionMsg,
            [string]$outputFile
        )
        try {
            Show-MessageAndWriteLogEntry -Message $functionMsg -Level INFO
            & $action
            Show-MessageAndWriteLogEntry -File $outputFile -Level SUCCESS
        }
        catch {
            $errorMessage = "Execution failed during '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
            Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
        }
    }


    function Get-LocalIpInfo {
        param(
            [string]$outputFile = "$networkFolder\local_ip_info.txt",
            [string]$csvOutputFile = "$networkFolder\local_ip_info.csv"
        )
        $netIPCommand = { Get-NetIPAddress | Select-Object -Property * }
        $netIPData = &$netIPCommand
        Write-OutputToFile -Command $netIPCommand -Data $netIPData -OutputFile $outputFile
        Save-OutputAsCsv -Data $netIPData -OutputFile $csvOutputFile

        $ipConfigCommand = { ipconfig /all }
        $ipConfigData = &$ipConfigCommand
        Write-OutputToFile -Command $ipConfigCommand -Data $ipConfigData -OutputFile $outputFile -Append
    }

    function Get-NetworkConfig {
        param(
            [string]$outputFile = "$networkFolder\network_config.txt"
        )
        $command = { Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq "True" } | Select-Object -Property * | Format-List }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-EstablishedConnections {
        param(
            [string]$outputFile = "$networkFolder\netstat_established_connections.txt"
        )
        $command = netstat -nao | Select-String "ESTA"

        foreach ($Element in $command) {
            $data = $Element -split " " | Where-Object { $_ -ne "" }
            New-Object -TypeName PSObject -Property @{
                "Local IP : Port#"              = $data[1];
                "Remote IP : Port#"             = $data[2];
                "Process ID"                    = $data[4];
                "Process Name"                  = ((Get-Process | Where-Object { $_.ID -eq $data[4] })).Name
                "Process File Path"             = ((Get-Process | Where-Object { $_.ID -eq $data[4] })).Path
                "Process Start Time"            = ((Get-Process | Where-Object { $_.ID -eq $data[4] })).StartTime
                "Associated DLLs and File Path" = ((Get-Process | Where-Object { $_.ID -eq $data[4] })).Modules | Select-Object @{ N = "Module"; E = { $_.FileName -join "; " } } | Out-String
            } | Out-File -Append -FilePath $outputFile
        }
    }


    function Get-AllConnections {
        param(
            [string]$outputFile = "$networkFolder\netstat_all_connections.txt"
        )
        $command = { netstat -nao }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-NetTcpConnections {
        param(
            [string]$outputFile = "$networkFolder\net_tcp_connections.txt",
            [string]$csvOutputFile = "$networkFolder\net_tcp_connections.csv"
        )
        $allCommand = { Get-NetTCPConnection | Select-Object -Property * | Sort-Object LocalAddress -Desc }
        $allData = &$allCommand
        Write-OutputToFile -Command $allCommand -Data $allData -OutputFile $outputFile
        Save-OutputAsCsv -Data $allData -OutputFile $csvOutputFile
    }


    function Get-DnsCache {
        param(
            [string]$outputFile = "$networkFolder\dns_cache.txt"
        )
        $command = { ipconfig /displaydns }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-DnsCacheByRecordName {
        param(
            [string]$outputFile = "$networkFolder\dns_cache_by_record_name.txt"
        )
        $command = { ipconfig /displaydns | Select-String "Record Name" | Sort-Object }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-NetworkShares {
        param(
            [string]$outputFile = "$networkFolder\network_shares.txt"
        )
        $command = { Get-ChildItem -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2" | Select-Object * -ExcludeProperty PS* }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    function Get-SmbShareData {
        param(
            [string]$outputFile = "$networkFolder\smb_shares.txt"
        )
        $command = { Get-SmbShare | Select-Object -Property * }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $workFlow = [ordered]@{
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

    foreach ($task in $workFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
