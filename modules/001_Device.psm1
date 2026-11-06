function Get-TriageDeviceData {
    <#
    .SYNOPSIS
        Collects hardware, operating system, disk, memory, session, and startup
        information about the computer (module 001_Device).

    .DESCRIPTION
        Runs a series of read-only collection tasks and writes each result as
        a text or CSV file in the module folder.  Tasks run one after another
        in this order:

            01.01_device_info.txt
                Overall record from Get-ComputerDetails: operating system,
                hardware, BIOS, license, time zone, uptime, and settings.
            01.02_PS_info.txt
                Sysinternals PsInfo (installed software, hotfixes, and disk
                volumes), run from the verified bin folder.
            01.03_computer_info.txt
                Output of `Get-ComputerInfo`.
            01.04_system_info1.txt
                Output of `systeminfo` in list format.
            01.05_system_info2.txt
                `Win32_ComputerSystem` properties.
            01.06_physical_memory.txt
                Installed memory modules (`Win32_PhysicalMemory`).
            01.07_env_vars.txt
                Environment variables of the running session.
            01.08_disk_partitions.csv
                Disk partitions (`Win32_DiskPartition`).
            01.09a_start_up_apps.txt,
            01.09b_start_up_apps.csv
                Startup commands (`Win32_StartupCommand`), plus the contents
                of the HKLM Run, RunOnce, and Policies\Explorer\Run keys
                (both 32-bit and 64-bit views) appended to the text file.
            01.10_motherboard.txt
                Motherboard properties (`Win32_BaseBoard`).
            01.11_disk_info.csv
                Volumes joined to their partitions and physical disks.
            01.12_key_folder_listing.csv
                List key folders present on the examined device.

    .PARAMETER DeviceFolder
        Path of the folder where this module writes its files.

        `Invoke-DfirTriageScan` creates it as `<ResultsFolder>\001_Device`.

    .INPUTS
        None.

        This function does not accept pipeline input.

    .OUTPUTS
        None.

        Results are written to files in DeviceFolder, and progress is written
        to the screen and the log.

    .EXAMPLE
        Get-TriageDeviceData `
            -DeviceFolder "E:\Triage\Case-2026-0142\001_Device"

        Writes the 01.xx files into that folder.

        The toolkit must already be loaded and its tools verified (see NOTES).

    .EXAMPLE
        Invoke-DfirTriageScan -ResultsFolder $Folder -Operator "J. Smith" `
            -CaseNumber "2026-0142" -Modules "001_Device"

        The usual way this module runs, on its own.

    .NOTES
        Requires an elevated session.  The tools used from bin (`PSInfo`,
        `systeminfo`) are looked up with `Get-TriageBinary`, which only works
        after `Initialize-TriageSystemTools` has run, so call this function
        through `Invoke-DfirTriageScan` rather than from a fresh session.

        Footprint: `PsInfo` is started with `-accepteula`, which creates the
        `HKCU\Software\Sysinternals\PsInfo\EulaAccepted` key in the registry
        of the account running the toolkit.  The code appends a note saying
        so to `PS_info.txt`.  Record it in the case notes.

        Each task is isolated: if one fails, the error is logged and the next
        task still runs.

        A task whose output file is missing or empty is also reported as an
        error.

    .LINK
        Invoke-DfirTriageScan

    .LINK
        Get-ComputerDetails

    .LINK
        Invoke-TriageTaskList
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceFolder
    )

    function Get-MiscDeviceData {
        param(
            [string]$TxtFile = (
                Join-Path -Path $DeviceFolder -ChildPath "01.01_device_info.txt"
            )
        )
        $Data = Get-ComputerDetails
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-SystemProcesses {
        param(
            [string]$TxtFile = (
                Join-Path -Path $DeviceFolder -ChildPath "01.02_PS_info.txt"
            )
        )
        & (Get-TriageBinary "PSInfo") -accepteula -s -h -d > $TxtFile 2>&1

        $Msg = "`n`nPsInfo was run with `-accepteula`, which creates `HKCU\Software\Sysinternals" +
            "\PsInfo\EulaAccepted (DWORD = 1)` in the `NTUSER.DAT` of the account used to run the " +
            "tool (<DOMAIN\user>). This change was made by the examiner's tool, not by the subject. " +
            "In the current execution order, the snapshot of that account's registry hive is taken " +
            "before PsInfo runs, so the collected copy will not contain the value."
        Add-Content -Path $TxtFile -Value $Msg -Encoding UTF8
    }


    function Get-CurrentComputerInfo {
        param(
            [string]$TxtFile = (
                Join-Path -Path $DeviceFolder -ChildPath "01.03_computer_info.txt"
            )
        )
        $Data = Get-ComputerInfo
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-SystemInfo1 {
        param(
            [string]$TxtFile = (
                Join-Path -Path $DeviceFolder -ChildPath "01.04_system_info1.txt"
            )
        )
        $Data = & (Get-TriageBinary "systeminfo") /FO LIST
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-SystemInfo2 {
        param(
            [string]$TxtFile = (
                Join-Path -Path $DeviceFolder -ChildPath "01.05_system_info2.txt"
            )
        )
        $Data = Get-CimInstance -ClassName Win32_ComputerSystem |
            Select-Object -Property *
        Write-OutputToFile -Data $Data -OutputFile $TxtFile -Append
    }


    function Get-PhysicalMemory {
        param(
            [string]$TxtFile = (
                Join-Path -Path $DeviceFolder -ChildPath "01.06_physical_memory.txt"
            )
        )
        $Data = Get-CimInstance -ClassName Win32_PhysicalMemory |
            Select-Object -Property *
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-EnvVars {
        param(
            [string]$TxtFile = (
                Join-Path -Path $DeviceFolder -ChildPath "01.07_env_vars.txt"
            )
        )
        $Data = Get-ChildItem -LiteralPath env: | Format-List
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-DiskPart {
        param(
            [string]$CsvFile = (
                Join-Path -Path $DeviceFolder -ChildPath "01.08_disk_partitions.csv"
            )
        )
        $Data = Get-CimInstance -ClassName Win32_DiskPartition |
            Select-Object -Property * |
            Sort-Object -Property Name
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile
    }

    function Get-StartUpApps {
        param(
            [string]$TxtFile = (
                Join-Path -Path $DeviceFolder -ChildPath "01.09a_start_up_apps.txt"
            ),
            [string]$CsvFile = (
                Join-Path -Path $DeviceFolder -ChildPath "01.09b_start_up_apps.csv"
            )
        )
        $Data = Get-CimInstance -ClassName Win32_StartupCommand |
            Select-Object -Property * |
            Sort-Object Caption
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        Write-OutputToFile -Data $Data -OutputFile $TxtFile

        $RunKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"
        )

        foreach($Key in $RunKeys) {
            "`n`nFrom : $Key`n" | Out-File -FilePath $TxtFile -Append -Encoding UTF8
            $KeyData = Invoke-RegistryCommand -Command { Get-ItemProperty $Key |
                Select-Object -Property * -ExcludeProperty PS* }

            if ($KeyData) {
                $KeyData | Out-File -FilePath $TxtFile -Append -Encoding UTF8
            }
            else {
                $Msg = "No data found for registry key [ $( $Key ) ]"
                $Msg | Out-File -FilePath $TxtFile -Append -Encoding UTF8
            }
        }
    }


    function Get-MotherboardInfo {
        param(
            [string]$TxtFile = (
                Join-Path -Path $DeviceFolder -ChildPath "01.10_motherboard.txt"
            )
        )
        $Data = Get-CimInstance -ClassName Win32_BaseBoard |
            Select-Object -Property *
        Write-OutputToFile -Data $Data -OutputFile $TxtFile
    }


    function Get-DiskInfo {
    <#
    .SYNOPSIS
        Gets a list of all connected volumes that have a drive letter assigned and then runs the
        `Get-Disk` command on each of the drives and saves the output to a .CSV file.
    .PARAMETER CsvFile
        Path of the file to which the output of this function will be saved.
    #>
        [CmdletBinding()]
        param(
            [string]$CsvFile = (
                Join-Path -Path $DeviceFolder -ChildPath "01.11_disk_info.csv"
            )
        )
        Get-Volume |
            Where-Object DriveLetter |
            ForEach-Object {
                $L = $_.DriveLetter; Get-Partition -DriveLetter $L `
                -ErrorAction SilentlyContinue |
                Get-Disk |
                Select-Object -Property @{
                    Name = "DriveLetter"
                    Expression = { $L }
                }, * -ExcludeProperty Cim*
            } |
            Sort-Object -Property DriveLetter |
            Select-Object -Property DriveLetter, DiskNumber, PartitionStyle, ProvisioningType, `
            OperationalStatus, HealthStatus, BusType, UniqueIdFormat, OfflineReason, ObjectID, `
            PassThroughClass, PassThroughIds, PassThroughNamespace, PassThroughServer, UniqueId, `
            AdapterSerialNumber, @{
                Name = "AllocatedSize (GB)"
                Expression = { "{0:N2}" -f ($_.AllocatedSize / 1GB) }
            }, BootFromDisk, FirmwareVersion, FriendlyName, Guid, IsBoot, IsClustered, `
            IsHighlyAvailable, IsOffline, IsReadOnly, IsScaleOut, IsSystem, `
            LargestFreeExtent, Location, LogicalSectorSize, Manufacturer, Model, Number, `
            NumberOfPartitions, Path, PhysicalSectorSize, @{
                Name = "SerialNumber"
                Expression = { "$( $_.SerialNumber )".Trim() }
            }, Signature, Size, PSComputerName |
            Export-Csv -Path $CsvFile -NoTypeInformation -Encoding UTF8
    }


    function Get-KeyFolderListing {
        param(
            [string]$CsvFile = (
                Join-Path -Path $DeviceFolder -ChildPath "01.12_key_folder_listing.csv"
            )
        )
        $Paths = @(
            "$env:SystemDrive\",
            "$env:SystemDrive\Users",
            $env:ProgramData,
            "$env:SystemDrive\Program Files",
            ${env:ProgramFiles(x86)}
        )
        foreach ($H in $global:TriageUserHives) {
            if ($H.ProfilePath) {
                $Paths += (Join-Path -Path $H.ProfilePath -ChildPath "Desktop"),
                    (Join-Path -Path $H.ProfilePath -ChildPath "Downloads")
            }
        }
        $Data = foreach ($P in $Paths) {
            Get-ChildItem -LiteralPath $P -Force -ErrorAction SilentlyContinue |
                Select-Object FullName, Attributes, Length, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
        }
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $Tasks = @(
        @{
            Action    = { Get-MiscDeviceData }
            Message   = "01.01_Gathering Overall Device Information..."
            Files     = "01.01_device_info.txt"
        }
        @{
            Action    = { Get-SystemProcesses }
            Message   = "01.02_Running SysInternals PSInfo.exe..."
            Files     = "01.02_PS_info.txt"
        }
        @{
            Action    = { Get-CurrentComputerInfo }
            Message   = "01.03_Parsing Computer Information..."
            Files     = "01.03_computer_info.txt"
        }
        @{
            Action    = { Get-SystemInfo1 }
            Message   = "01.04_Parsing System Information (First)..."
            Files     = "01.04_system_info1.txt"
        }
        @{
            Action    = { Get-SystemInfo2 }
            Message   = "01.05_Parsing System Information (Second)..."
            Files     = "01.05_system_info2.txt"
        }
        @{
            Action    = { Get-PhysicalMemory }
            Message   = "01.06_Getting Physical Memory Information..."
            Files     = "01.06_physical_memory.txt"
        }
        @{
            Action    = { Get-EnvVars }
            Message   = "01.07_Getting Environment Variables..."
            Files     = "01.07_env_vars.txt"
        }
        @{
            Action    = { Get-DiskPart }
            Message   = "01.08_Getting Disk Partition Information..."
            Files     = "01.08_disk_partitions.csv"
        }
        @{
            Action    = { Get-StartUpApps }
            Message   = "01.09_Parsing Startup Apps..."
            Files     = "01.09a_start_up_apps.txt",
                        "01.09b_start_up_apps.csv"
        }
        @{
            Action    = { Get-MotherboardInfo }
            Message   = "01.10_Gathering Motherboard Properties..."
            Files     = "01.10_motherboard.txt"
        }
        @{
            Action    = { Get-DiskInfo }
            Message   = "01.11_Gathering Disk Information..."
            Files     = "01.11_disk_info.csv"
        }
        @{
            Action    = { Get-KeyFolderListing }
            Message   = "01.12_Listing key folders..."
            Files     = "01.12_key_folder_listing.csv"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $DeviceFolder

}
