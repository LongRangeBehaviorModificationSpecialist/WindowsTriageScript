function Get-TriageRawArtifactsData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RawFolder
    )

    $Cfg      = Get-TriageConfig -Key "RawArtifacts"
    $SysRoot  = $env:SystemRoot
    $SysDrive = $env:SystemDrive
    $Manifest = [System.Collections.Generic.List[object]]::new()

    # Unknown (for example a UNC path): do not block
    $FreeGb = 1e6
    try {
        $FreeGb = (New-Object System.IO.DriveInfo ([System.IO.Path]::GetPathRoot($RawFolder))).AvailableFreeSpace / 1GB
    }
    catch { }

    function Get-FolderFiles {
        param(
            [string]$Folder,
            [string]$DestBase,
            [string]$Filter = "*"
        )
        if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
            return
        }
        $Root = (Resolve-Path -LiteralPath $Folder).Path.TrimEnd("\")
        Get-ChildItem -LiteralPath $Folder -Recurse -Force -File -Filter $Filter -ErrorAction SilentlyContinue | ForEach-Object {
            [PSCustomObject]@{
                Kind   = "File"
                Source = $_.FullName
                Dest   = Join-Path -Path $DestBase -ChildPath $_.FullName.Substring($Root.Length + 1)
            }
        }
    }

    # Each set returns items: Kind = File | Raw | RegSave | Folder, a Source and a Dest (relative to $RawFolder)
    $Sets = [ordered]@{
        SystemHives = {
            foreach ($Hive in "SYSTEM", "SOFTWARE", "SAM", "SECURITY") {
                [PSCustomObject]@{
                    Kind   = "RegSave"
                    Source = "HKLM\$Hive"
                    Dest   = "Registry\$Hive.regsave"
                }
                foreach ($Extension in "", ".LOG1", ".LOG2") {
                    # On-disk file plus transaction logs (locked: needs RawCopy)
                    [PSCustomObject]@{
                        Kind   = "File"
                        Source = "$SysRoot\System32\config\$Hive$Extension"
                        Dest   = "Registry\ondisk\$Hive$Extension"
                    }
                }
            }
        }
        Amcache = {
            foreach ($Extension in "", ".LOG1", ".LOG2") {
                [PSCustomObject]@{
                    Kind   = "File"
                    Source = "$SysRoot\appcompat\Programs\Amcache.hve$Extension"
                    Dest   = "Amcache\Amcache.hve$Extension"
                }
            }
        }
        UserHives = {
            foreach ($Hive in ($global:TriageUserHives | Where-Object ProfilePath)) {
                $Base = "Users\$( $Hive.Sid )"
                $Live = $Hive.Root -and ($Hive.Root -notlike "*TRIAGE_*")
                $Cls  = Join-Path -Path $Hive.ProfilePath -ChildPath "AppData\Local\Microsoft\Windows\UsrClass.dat"
                foreach ($Extension in "", ".LOG1", ".LOG2") {
                    [PSCustomObject]@{
                        Kind   = "File"
                        Source = "$Cls$Extension"
                        Dest   = "$Base\UsrClass.dat$Extension"
                    }
                    # Logged-off users' NTUSER.DAT is already preserved in Registry_Hives
                    # Copy the original for logged-on users
                    if ($Live) {
                        [PSCustomObject]@{
                            Kind   = "File"
                            Source = (Join-Path -Path $Hive.ProfilePath -ChildPath "NTUSER.DAT$Extension")
                            Dest   = "$Base\NTUSER.DAT$Extension"
                        }
                    }
                }
                if ($Live) {
                    [PSCustomObject]@{
                        Kind = "RegSave"
                        Source = "HKU\$( $Hive.Sid )_Classes"
                        Dest = "$Base\UsrClass.regsave"
                    }
                }
            }
        }
        Prefetch = { Get-FolderFiles -Folder "$SysRoot\Prefetch" -DestBase "Prefetch" -Filter "*.pf" }
        Srum     = { Get-FolderFiles -Folder "$SysRoot\System32\sru" -DestBase "SRUM" }
        LnkAndJumpLists = {
            $Map = [ordered]@{
                "AppData\Roaming\Microsoft\Windows\Recent" = "Recent";
                "AppData\Roaming\Microsoft\Office\Recent" = "OfficeRecent"
            }
            foreach ($Hive in ($global:TriageUserHives | Where-Object ProfilePath)) {
                foreach ($Rel in $Map.Keys) {
                    Get-FolderFiles -Folder (Join-Path -Path $Hive.ProfilePath -ChildPath $Rel) -DestBase "Users\$( $Hive.Sid )\$( $Map[$Rel] )"
                }
            }
        }
        BrowserDatabases = {
            $Wanted = @{
                Chromium = "History", "Favicons", "Shortcuts", "Top Sites", "Web Data", "Network\Cookies", "Cookies"
                Firefox  = "places.sqlite", "cookies.sqlite", "formhistory.sqlite", "favicons.sqlite"
            }
            foreach ($Hive in ($global:TriageUserHives | Where-Object ProfilePath)) {
                foreach ($Browser in (Get-TriageConfig -Key "Browsers")) {
                    $Root = Join-Path -Path $Hive.ProfilePath -ChildPath $Browser.Root
                    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
                        continue
                    }
                    foreach ($UserProfile in (Get-ChildItem -LiteralPath $Root -Directory -Force -ErrorAction SilentlyContinue)) {
                        foreach ($File in $Wanted[$Browser.Type]) {
                            foreach ($Suffix in "", "-wal", "-journal") {
                                $Source = Join-Path -Path $UserProfile.FullName -ChildPath "$File$Suffix"
                                if (Test-Path -LiteralPath $Source -PathType Leaf) {
                                    [PSCustomObject]@{
                                        Kind = "File"
                                        Source = $Source
                                        Dest = "Browsers\$( $Hive.Sid )\$( $Browser.Name )\$( $UserProfile.Name )\$File$Suffix"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        StartupFolders = {
            Get-FolderFiles -Folder "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp" -DestBase "Startup\AllUsers"
            foreach ($Hive in ($global:TriageUserHives | Where-Object ProfilePath)) {
                Get-FolderFiles -Folder (Join-Path -Path $Hive.ProfilePath -ChildPath "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup") -DestBase "Startup\$( $Hive.Sid )"
            }
        }
        WmiRepository = { Get-FolderFiles -Folder "$SysRoot\System32\wbem\Repository" -DestBase "WMI_Repository" }
        Bits          = { Get-FolderFiles -Folder "$env:ProgramData\Microsoft\Network\Downloader" -DestBase "BITS" }
        WindowsUpdate = {
            Get-FolderFiles -Folder "$SysRoot\Logs\WindowsUpdate" -DestBase "WindowsUpdate" -Filter "*.etl"
            [PSCustomObject]@{
                Kind   = "File"
                Source = "$SysRoot\SoftwareDistribution\ReportingEvents.log"
                Dest   = "WindowsUpdate\ReportingEvents.log"
            }
        }
        Defender = {
            $Def = "$env:ProgramData\Microsoft\Windows Defender"
            [PSCustomObject]@{
                Kind   = "Folder"
                Source = "$Def\Quarantine"
                Dest   = "Defender\Quarantine"
            }
            [PSCustomObject]@{
                Kind   = "Folder"
                Source = "$Def\Scans\History"
                Dest   = "Defender\ScanHistory"
            }
        }
        # Single quotes matter: in double quotes PowerShell would expand $MFT and $J as variables
        Mft = {
            [PSCustomObject]@{
                Kind   = "Raw"
                Source = ('{0}\$MFT' -f $SysDrive)
                Dest   = "NTFS\MFT"
            }
        }
        UsnJrnl = {
            [PSCustomObject]@{
                Kind   = "Raw"
                Source = ('{0}\$Extend\$UsnJrnl:$J' -f $SysDrive)
                Dest   = "NTFS\UsnJrnl_J"
            }
        }
    }

    foreach ($Set in $Cfg.Enabled) {
        if (-not $Sets.Contains($Set)) {
            Show-Message -Message "Unknown raw artifact set [ $Set ] in the configuration file." -Level WARNING -AddToLog
            continue
        }
        if ($Set -in $Cfg.LargeSets -and $FreeGb -lt $Cfg.MinFreeGbForLargeSets) {
            Show-Message -Message "Skipping [ $Set ] => only $( [int]$FreeGb ) GB free (minimum $( $Cfg.MinFreeGbForLargeSets ) GB)." -Level WARNING -AddToLog
            continue
        }

        Invoke-TriageTask -Message "Copying raw artifacts => $Set..." -Action {
            $Rows = foreach ($Item in @(& $Sets[$Set])) {
                $Dest = Join-Path -Path $RawFolder -ChildPath $Item.Dest
                $R = switch ($Item.Kind) {
                    "File"    { Copy-TriageFile -Source $Item.Source -Destination $Dest }
                    "Raw"     { Copy-TriageRawFile -Source $Item.Source -Destination $Dest }
                    "RegSave" { Save-TriageRegistryHive -HiveKey $Item.Source -Destination $Dest }
                    "Folder"  { Copy-TriageFolderBackup -Source $Item.Source -Destination $Dest }
                }
                $R | Add-Member -NotePropertyName Set -NotePropertyValue $Set -PassThru
            }
            foreach ($R in @($Rows)) {
                $Manifest.Add($R)
            }

            $Ok     = @($Rows | Where-Object Status -eq "OK").Count
            $Locked = @($Rows | Where-Object Status -eq "Locked").Count
            $Failed = @($Rows | Where-Object Status -eq "Failed").Count
            if ($Failed) {
                Show-Message -Message "[ $Set ] $Ok copied, $Failed failed, $Locked locked. See raw_artifacts_manifest.csv." -Level ERROR -AddToLog
            }
            elseif ($Locked) {
                Show-Message -Message "[ $Set ] $Ok copied, $Locked locked (RawCopy needed)." -Level WARNING -AddToLog
            }
            else {
                Show-Message -Message "[ $Set ] $Ok file(s) copied." -Level INFO -AddToLog
            }
        }
    }

    Write-OutputToCsv -Data $Manifest -OutputFile (Join-Path -Path $RawFolder -ChildPath "raw_artifacts_manifest.csv")
}