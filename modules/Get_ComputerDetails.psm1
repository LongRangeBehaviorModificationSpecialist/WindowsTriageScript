function Get-ComputerDetails {
    [CmdletBinding()]
    param()

    begin {
        $ComputerName = $env:computername

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
    }
    process {
        try {
            $Win32OperatingSystem     = Get-CimInstance -ClassName Win32_OperatingSystem
            $Win32ComputerSystem      = Get-CimInstance -ClassName Win32_ComputerSystem
            $Win32Bios                = Get-CimInstance -ClassName Win32_BIOS
            $Win32Processor           = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
            $SoftwareLicensingProduct = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%'" | Where-Object { $_.PartialProductKey }

            $DataProps = [ordered]@{
                Host        = $env:COMPUTERNAME
                DateScanned = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            }

            $MergeProperties = {
                param($SourceInstance)

                if ($SourceInstance) {

                    foreach ($Prop in $SourceInstance.CimInstanceProperties) {

                        if (-not $DataProps.Contains($Prop.Name)) {
                            $DataProps[$Prop.Name] = $Prop.Value
                        }
                    }
                }
            }

            & $MergeProperties $Win32OperatingSystem
            & $MergeProperties $Win32ComputerSystem
            & $MergeProperties $Win32Processor
            & $MergeProperties $Win32Bios

            if ($DataProps.CurrentTimeZone) {
                $DataProps.CurrentTimeZone = $DataProps.CurrentTimeZone / 60
            }

            if ($null -ne $DataProps.DomainRole) {
                $DataProps.DomainRole = ([DomainRole]$DataProps.DomainRole).ToString()
            }

            if ($DataProps.BiosVersion) {
                $DataProps.BiosVersion = $DataProps.BiosVersion -join " | "
            }

            $UpTime = (Get-Date) - $Win32OperatingSystem.LastBootUpTime
            $DataProps["UpTime"] = "{0}:{1}:{2}:{3}" -f $UpTime.Days, $UpTime.Hours, $UpTime.Minutes, $UpTime.Seconds

            $NetAccountsLine = net accounts | Select-String -Pattern "Minimum password length"
            $DataProps["MinimumPasswordLength"] = if ($NetAccountsLine) { $NetAccountsLine.ToString().Split()[-1] } else { $null }

            $UsbStor = Get-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Services\USBStor" -Name "Start" -ErrorAction SilentlyContinue
            $DataProps["USBStorageLock"] = if ($UsbStor) { $UsbStor.Start } else { $null }

            if ($SoftwareLicensingProduct) {
                $DataProps["LicenseType"]   = ($SoftwareLicensingProduct.Description).Split(",")[1].Trim()
                $DataProps["LicenseStatus"] = ([LicenseStatus]$SoftwareLicensingProduct.LicenseStatus).ToString()
            }
            else {
                $DataProps["LicenseType"]   = $null
                $DataProps["LicenseStatus"] = $null
            }

            $DataProps["BIOSInstallDate"]  = $Win32Bios.InstallDate
            $DataProps["BIOSManufacturer"] = $Win32Bios.Manufacturer
            $DataProps["BIOSSerialNumber"] = $Win32Bios.SerialNumber

            [PSCustomObject]$DataProps | Select-Object Host, DateScanned, CurrentTimeZone, InstallDate, LastBootUpTime, UpTime, LocalDateTime, BootDevice, BootROMSupported, BootupState, ChassisBootupState, DataExecutionPrevention_32BitApplications, DataExecutionPrevention_Available, DataExecutionPrevention_Drivers, DataExecutionPrevention_SupportPolicy, MinimumPasswordLength, USBStorageLock, Debug, EncryptionLevel, AdminPasswordStatus, Description, Distributed, OSArchitecture, OSProductSuite, OSType, OperatingSystemSKU, Organization, OtherTypeDescription, PortableOperatingSystem, ProductType, RegisteredUser, ServicePackMajorVersion, ServicePackMinorVersion, Status, SuiteMask, BuildNumber, Caption, LicenseType, LicenseStatus, SystemDevice, SystemDirectory, SystemDrive, MUILanguages, Version, WindowsDirectory, DNSHostName, DaylightInEffect, Domain, DomainRole, EnableDaylightSavingsTime, PrimaryOwnerContact, PrimaryOwnerName, SupportContactDescription, UserName, Manufacturer, Model, NetworkServerModeEnabled, HypervisorPresent, SystemSKUNumber, ThermalState, BIOSVersion, BIOSInstallDate, BIOSManufacturer, PrimaryBIOS, BIOSReleaseDate, SMBIOSBIOSVersion, SMBIOSMajorVersion, SMBIOSMinorVersion, SMBIOSPresent, BIOSSerialNumber, SystemBiosMajorVersion, SystemBiosMinorVersion, VirtualizationFirmwareEnabled
        }
        catch {
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )' on $( $Computer ). Error => $( $_.Exception.Message )"
            Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
        }
    }
}
