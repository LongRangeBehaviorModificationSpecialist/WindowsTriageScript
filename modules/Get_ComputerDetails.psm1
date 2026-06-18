function Get-ComputerDetails {
    [CmdletBinding()]
    param()

    Enum DomainRole {
        StandaloneWorkstation   = 0
        MemberWorkstation       = 1
        StandaloneServer        = 2
        MemberServer            = 3
        BackupDomainController  = 4
        PrimaryDomainController = 5
    }

    Enum LicenseStatus {
        Unlicensed      = 0
        Licensed        = 1
        OOBGrace        = 2
        OOTGrace        = 3
        NonGenuineGrace = 4
        Notification    = 5
        ExtendedGrace   = 6
    }

    try {
        $win32_operating_system     = Get-CimInstance -ClassName Win32_OperatingSystem
        $win32_computer_system      = Get-CimInstance -ClassName Win32_ComputerSystem
        $win32_bios                 = Get-CimInstance -ClassName Win32_BIOS
        $win32_processor            = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
        $software_licensing_product = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%'" | Where-Object { $_.PartialProductKey }

        $data_props = [ordered]@{
            Host        = $env:COMPUTERNAME
            DateScanned = (Get-Date)
        }

        $merge_properties = {
            param($source_instance)

            if ($source_instance) {

                foreach ($prop in $source_instance.CimInstanceProperties) {

                    if (-not $data_props.Contains($prop.Name)) {
                        $data_props[$prop.Name] = $prop.Value
                    }
                }
            }
        }

        & $merge_properties $win32_operating_system
        & $merge_properties $win32_computer_system
        & $merge_properties $win32_processor
        & $merge_properties $win32_bios

        if ($data_props.CurrentTimeZone) {
            $data_props.CurrentTimeZone = $data_props.CurrentTimeZone / 60
        }

        if ($null -ne $data_props.DomainRole) {
            $data_props.DomainRole = ([DomainRole]$data_props.DomainRole).ToString()
        }

        if ($data_props.BiosVersion) {
            $data_props.BiosVersion = $data_props.BiosVersion -join " | "
        }

        $up_time = (Get-Date) - $win32_operating_system.LastBootUpTime
        $data_props["UpTime"] = "{0}:{1}:{2}:{3}" -f $up_time.Days, $up_time.Hours, $up_time.Minutes, $up_time.Seconds

        $net_accounts_line = net accounts | Select-String -Pattern "Minimum password length"
        $data_props["MinimumPasswordLength"] = if ($net_accounts_line) { $net_accounts_line.ToString().Split()[-1] } else { $null }

        $usb_stor = Get-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Services\USBStor" -Name "Start" -ErrorAction SilentlyContinue
        $data_props["USBStorageLock"] = if ($usb_stor) { $usb_stor.Start } else { $null }

        if ($software_licensing_product) {
            $data_props["LicenseType"]   = ($software_licensing_product.Description).Split(",")[1].Trim()
            $data_props["LicenseStatus"] = ([LicenseStatus]$software_licensing_product.LicenseStatus).ToString()
        }
        else {
            $data_props["LicenseType"]   = $null
            $data_props["LicenseStatus"] = $null
        }

        $data_props["BIOSInstallDate"]  = $win32_bios.InstallDate
        $data_props["BIOSManufacturer"] = $win32_bios.Manufacturer
        $data_props["BIOSSerialNumber"] = $win32_bios.SerialNumber

        [PSCustomObject]$data_props | Select-Object Host, DateScanned, CurrentTimeZone, InstallDate, LastBootUpTime, UpTime, LocalDateTime, BootDevice, BootROMSupported, BootupState, ChassisBootupState, DataExecutionPrevention_32BitApplications, DataExecutionPrevention_Available, DataExecutionPrevention_Drivers, DataExecutionPrevention_SupportPolicy, MinimumPasswordLength, USBStorageLock, Debug, EncryptionLevel, AdminPasswordStatus, Description, Distributed, OSArchitecture, OSProductSuite, OSType, OperatingSystemSKU, Organization, OtherTypeDescription, PortableOperatingSystem, ProductType, RegisteredUser, ServicePackMajorVersion, ServicePackMinorVersion, Status, SuiteMask, BuildNumber, Caption, LicenseType, LicenseStatus, SystemDevice, SystemDirectory, SystemDrive, MUILanguages, Version, WindowsDirectory, DNSHostName, DaylightInEffect, Domain, DomainRole, EnableDaylightSavingsTime, PrimaryOwnerContact, PrimaryOwnerName, SupportContactDescription, UserName, Manufacturer, Model, NetworkServerModeEnabled, HypervisorPresent, SystemSKUNumber, ThermalState, BIOSVersion, BIOSInstallDate, BIOSManufacturer, PrimaryBIOS, BIOSReleaseDate, SMBIOSBIOSVersion, SMBIOSMajorVersion, SMBIOSMinorVersion, SMBIOSPresent, BIOSSerialNumber, SystemBiosMajorVersion, SystemBiosMinorVersion, VirtualizationFirmwareEnabled
    }
    catch {
        $error_msg = "Execution failed during `"$($MyInvocation.MyCommand.Name)`". Error: $($_.Exception.Message)"
        Show-MessageAndWriteLogEntry -Msg $error_msg -Level ERROR
    }
}
