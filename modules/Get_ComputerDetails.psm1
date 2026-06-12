function Get-ComputerDetails {
    [CmdletBinding()]
    param()

    Enum DomainRole {
        StandaloneWorkstation = 0
        MemberWorkstation = 1
        StandaloneServer = 2
        MemberServer = 3
        BackupDomainController = 4
        PrimaryDomainController = 5
    }

    Enum LicenseStatus {
        Unlicensed = 0
        Licensed = 1
        OOBGrace = 2
        OOTGrace = 3
        NonGenuineGrace = 4
        Notification = 5
        ExtendedGrace = 6
    }

    try {
        $win32_OperatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem
        $win32_ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        $win32_BIOS = Get-CimInstance -ClassName Win32_BIOS
        $win32_Processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
        $softwareLicensingProduct = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%'" | Where-Object { $_.PartialProductKey }

        $dataProps = [ordered]@{
            Host        = $env:COMPUTERNAME
            DateScanned = (Get-Date)
        }

        $mergeProperties = {
            param($sourceInstance)

            if ($sourceInstance) {

                foreach ($prop in $sourceInstance.CimInstanceProperties) {

                    if (-not $dataProps.Contains($prop.Name)) {
                        $dataProps[$prop.Name] = $prop.Value
                    }
                }
            }
        }

        & $mergeProperties $win32_OperatingSystem
        & $mergeProperties $win32_ComputerSystem
        & $mergeProperties $win32_Processor
        & $mergeProperties $win32_BIOS

        if ($dataProps.CurrentTimeZone) {
            $dataProps.CurrentTimeZone = $dataProps.CurrentTimeZone / 60
        }

        if ($null -ne $dataProps.DomainRole) {
            $dataProps.DomainRole = ([DomainRole]$dataProps.DomainRole).ToString()
        }

        if ($dataProps.BiosVersion) {
            $dataProps.BiosVersion = $dataProps.BiosVersion -join " | "
        }

        $upTime = (Get-Date) - $win32_OperatingSystem.LastBootUpTime
        $dataProps["UpTime"] = "{0}:{1}:{2}:{3}" -f $uptime.Days, $upTime.Hours, $upTime.Minutes, $upTime.Seconds

        $netAccountsLine = net accounts | Select-String -Pattern "Minimum password length"
        $dataProps["MinimumPasswordLength"] = if ($netAccountsLine) { $netAccountsLine.ToString().Split()[-1] } else { $null }

        $usbStor = Get-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Services\USBStor" -Name "Start" -ErrorAction SilentlyContinue
        $dataProps["USBStorageLock"] = if ($usbStor) { $usbStor.Start } else { $null }

        if ($softwareLicensingProduct) {
            $dataProps["LicenseType"] = ($softwareLicensingProduct.Description).Split(",")[1].Trim()
            $dataProps["LicenseStatus"] = ([LicenseStatus]$softwareLicensingProduct.LicenseStatus).ToString()
        }
        else {
            $dataProps["LicenseType"] = $null
            $dataProps["LicenseStatus"] = $null
        }

        $dataProps["BIOSInstallDate"] = $win32_BIOS.InstallDate
        $dataProps["BIOSManufacturer"] = $win32_BIOS.Manufacturer
        $dataProps["BIOSSerialNumber"] = $win32_BIOS.SerialNumber

        [PSCustomObject]$dataProps | Select-Object Host, DateScanned, CurrentTimeZone, InstallDate, LastBootUpTime, UpTime, LocalDateTime, BootDevice, BootROMSupported, BootupState, ChassisBootupState, DataExecutionPrevention_32BitApplications, DataExecutionPrevention_Available, DataExecutionPrevention_Drivers, DataExecutionPrevention_SupportPolicy, MinimumPasswordLength, USBStorageLock, Debug, EncryptionLevel, AdminPasswordStatus, Description, Distributed, OSArchitecture, OSProductSuite, OSType, OperatingSystemSKU, Organization, OtherTypeDescription, PortableOperatingSystem, ProductType, RegisteredUser, ServicePackMajorVersion, ServicePackMinorVersion, Status, SuiteMask, BuildNumber, Caption, LicenseType, LicenseStatus, SystemDevice, SystemDirectory, SystemDrive, MUILanguages, Version, WindowsDirectory, DNSHostName, DaylightInEffect, Domain, DomainRole, EnableDaylightSavingsTime, PrimaryOwnerContact, PrimaryOwnerName, SupportContactDescription, UserName, Manufacturer, Model, NetworkServerModeEnabled, HypervisorPresent, SystemSKUNumber, ThermalState, BIOSVersion, BIOSInstallDate, BIOSManufacturer, PrimaryBIOS, BIOSReleaseDate, SMBIOSBIOSVersion, SMBIOSMajorVersion, SMBIOSMinorVersion, SMBIOSPresent, BIOSSerialNumber, SystemBiosMajorVersion, SystemBiosMinorVersion, VirtualizationFirmwareEnabled
    }
    catch {
        $errorMessage = "Execution failed during '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
        Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
    }
}
