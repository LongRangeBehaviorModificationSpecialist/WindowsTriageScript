function Get-ComputerDetails {
    <#
    .SYNOPSIS
        Returns one object describing the computer's operating system,
        hardware, BIOS, licensing, and a few security settings.

    .DESCRIPTION
        Queries these CIM classes: Win32_OperatingSystem,
        Win32_ComputerSystem, Win32_BIOS, the first Win32_Processor,
        and SoftwareLicensingProduct (the Windows product that has a partial
        product key).

        Their properties are merged into one record; when two classes share
        a property name, the first one read is kept.

        The function then adds or converts some values:
            DateScanned
                The current time in UTC, in ISO 8601 form.
            CurrentTimeZone
                Converted from minutes to hours.
            DomainRole
                Converted from a number to a name, such as
                `MemberWorkstation`.
            BiosVersion
                Joined into one string, with " | " between items.
            UpTime
                Days:Hours:Minutes:Seconds since the last boot.
            MinimumPasswordLength
                Read from "net accounts" (a verified copy from the bin
                folder).
            USBStorageLock
                The Start value of the USBStor service; `4` normally means
                USB storage is disabled, `3` means it is allowed. $null if
                the key is missing.
            LicenseType and LicenseStatus
                From the Windows licensing record; status is shown as a name,
                such as Licensed or OOTGrace.
            BIOS date, vendor, and serial number.

        The result is a single object with about 80 properties in a fixed
        order (host and scan time first, then operating system, license,
        domain, hardware, and BIOS). A value that does not apply to the
        computer is `$null`.

    .INPUTS
        None.

        This function does not accept pipeline input.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        One object. Useful properties include Host, DateScanned,
        CurrentTimeZone, InstallDate, LastBootUpTime, UpTime, Caption,
        Version, BuildNumber, OSArchitecture, Domain, DomainRole,
        Manufacturer, Model, LicenseStatus, MinimumPasswordLength,
        USBStorageLock, BIOSVersion, and BIOSSerialNumber.

    .EXAMPLE
        Get-ComputerDetails

        Returns the full computer record.

    .EXAMPLE
        Get-ComputerDetails | Select-Object Host, Caption, Version,`
            DateScanned, USBStorageLock

        Shows only a few key properties.

    .NOTES
        All queries are read-only.  If `net accounts` fails, a warning is
        logged and MinimumPasswordLength is left empty; the rest of the record
        is still returned. If a CIM query fails, the whole function logs an
        error and returns nothing.

        `LicenseType` is taken from the second comma-separated part of the
        license description, so an unusual description format can leave it
        empty or incorrect.

    .LINK
        Get-TriageBinary
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param()

    $ComputerName = $env:COMPUTERNAME

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
        $Win32OperatingSystem     = Get-CimInstance -ClassName Win32_OperatingSystem
        # $Win32ComputerSystem      = Get-CimInstance -ClassName Win32_ComputerSystem
        $Win32Bios                = Get-CimInstance -ClassName Win32_BIOS
        $Win32Processor           = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
        $SoftwareLicensingProduct = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter `
            "Name like 'Windows%'" | Where-Object { $_.PartialProductKey }

        $DataProps = [ordered]@{
            Host = $env:COMPUTERNAME
            DateScanned = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }

        $MergeProperties = {
            param(
                $SourceInstance
            )

            if ($SourceInstance) {
                foreach ($Prop in $SourceInstance.CimInstanceProperties) {
                    if (-not $DataProps.Contains($Prop.Name)) {
                        $DataProps[$Prop.Name] = $Prop.Value
                    }
                }
            }
        }

        & $MergeProperties $Win32OperatingSystem
        # & $MergeProperties $Win32ComputerSystem
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

        $UpTime              = (Get-Date) - $Win32OperatingSystem.LastBootUpTime
        $DataProps["UpTime"] = "$( $UpTime.Days ):$( $UpTime.Hours ):$( $UpTime.Minutes ):$( $UpTime.Seconds )"

        $DataProps["MinimumPasswordLength"] = $null
        try {
            # Trusted copy, with both output streams captured so nothing reaches the screen
            $NetOut = @(& (Get-TriageBinary "net") accounts 2>&1 | ForEach-Object { "$_" })

            if ($LASTEXITCODE -eq 0) {
                $NetLine = $NetOut | Select-String -Pattern "Minimum password length"
                if ($NetLine) {
                    $DataProps["MinimumPasswordLength"] = $NetLine.ToString().Split()[-1]
                }
            }
            else {
                $NetMsg = "The `"net accounts`" command returned exit code $( $LASTEXITCODE ); " +
                    "minimum password length not recorded. First output line => " +
                    "$( $NetOut | Select-Object -First 1 )"
                Show-Message -Message $NetMsg -Level WARNING -AddToLog
            }

        }
        catch {
            Show-Message -Message "Minimum password length not recorded => $( $_.Exception.Message )" `
                -Level WARNING -AddToLog
        }

        # $NetAccountsLine = & (Get-TriageBinary "net") accounts | Select-String -Pattern "Minimum password length"
        # $DataProps["MinimumPasswordLength"] = if ($NetAccountsLine) { $NetAccountsLine.ToString().Split()[-1] } else { $null }

        $UsbStor = Get-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Services\USBStor" `
            -Name "Start" `
            -ErrorAction SilentlyContinue
        $DataProps["USBStorageLock"] = if ($UsbStor) {
                $UsbStor.Start
            }
            else {
                $null
            }

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

        [PSCustomObject]$DataProps | Select-Object Host, DateScanned, CurrentTimeZone, `
        InstallDate, LastBootUpTime, UpTime, LocalDateTime, BootDevice, BootROMSupported, `
        BootupState, ChassisBootupState,DataExecutionPrevention_32BitApplications, `
        DataExecutionPrevention_Available, DataExecutionPrevention_Drivers, `
        DataExecutionPrevention_SupportPolicy, MinimumPasswordLength, USBStorageLock, `
        Debug, EncryptionLevel, AdminPasswordStatus, Description, Distributed, OSArchitecture, `
        OSProductSuite, OSType, OperatingSystemSKU, Organization, OtherTypeDescription, `
        PortableOperatingSystem, ProductType, RegisteredUser, ServicePackMajorVersion, `
        ServicePackMinorVersion, Status, SuiteMask, BuildNumber, Caption, LicenseType, `
        LicenseStatus, SystemDevice, SystemDirectory, SystemDrive, MUILanguages, Version, `
        WindowsDirectory, DNSHostName, DaylightInEffect, Domain, DomainRole, `
        EnableDaylightSavingsTime, PrimaryOwnerContact, PrimaryOwnerName, `
        SupportContactDescription, UserName, Manufacturer, Model, NetworkServerModeEnabled, `
        HypervisorPresent, SystemSKUNumber, ThermalState, BIOSVersion, BIOSInstallDate, `
        BIOSManufacturer, PrimaryBIOS, BIOSReleaseDate, SMBIOSBIOSVersion, SMBIOSMajorVersion, `
        SMBIOSMinorVersion, SMBIOSPresent, BIOSSerialNumber, SystemBiosMajorVersion, `
        SystemBiosMinorVersion, VirtualizationFirmwareEnabled
    }
    catch {
        $ErrorMsg = "Execution failed during $( $MyInvocation.MyCommand.Name ) on $( $ComputerName ). " +
            "Error => $( $_.Exception.Message )"
        Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
    }
}
