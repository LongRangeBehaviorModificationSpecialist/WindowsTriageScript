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
            [pscustomobject]@{
                Kind   = "File"
                Source = $_.FullName
                Dest   = Join-Path -Path $DestBase -ChildPath $_.FullName.Substring($Root.Length + 1)
            }
        }
    }

    # Each set returns items: Kind = File | Raw | RegSave | Folder, a Source and a Dest (relative to $RawFolder)
    $Sets = [ordered]@{
        SystemHives = {
            foreach ($H in "SYSTEM", "SOFTWARE", "SAM", "SECURITY") {
                [pscustomobject]@{
                    Kind   = "RegSave"
                    Source = "HKLM\$H"
                    Dest   = "Registry\$H.regsave"
                }
                foreach ($Ext in "", ".LOG1", ".LOG2") {
                    # On-disk file plus transaction logs (locked: needs RawCopy)
                    [pscustomobject]@{
                        Kind   = "File"
                        Source = "$SysRoot\System32\config\$H$Ext"
                        Dest   = "Registry\ondisk\$H$Ext"
                    }
                }
            }
        }
        Amcache = {
            foreach ($Ext in "", ".LOG1", ".LOG2") {
                [pscustomobject]@{
                    Kind   = "File"
                    Source = "$SysRoot\appcompat\Programs\Amcache.hve$Ext"
                    Dest   = "Amcache\Amcache.hve$Ext"
                }
            }
        }
        UserHives = {
            foreach ($H in ($global:TriageUserHives | Where-Object ProfilePath)) {
                $Base = "Users\$( $H.Sid )"
                $Live = $H.Root -and ($H.Root -notlike "*TRIAGE_*")
                $Cls  = Join-Path -Path $H.ProfilePath -ChildPath "AppData\Local\Microsoft\Windows\UsrClass.dat"
                foreach ($Ext in "", ".LOG1", ".LOG2") {
                    [pscustomobject]@{
                        Kind   = "File"
                        Source = "$Cls$Ext"
                        Dest   = "$Base\UsrClass.dat$Ext"
                    }
                    # Logged-off users' NTUSER.DAT is already preserved in Registry_Hives
                    # Copy the original for logged-on users
                    if ($Live) {
                        [pscustomobject]@{
                            Kind   = "File"
                            Source = (Join-Path -Path $H.ProfilePath -ChildPath "NTUSER.DAT$Ext")
                            Dest   = "$Base\NTUSER.DAT$Ext"
                        }
                    }
                }
                if ($Live) {
                    [pscustomobject]@{
                        Kind = "RegSave"
                        Source = "HKU\$( $H.Sid )_Classes"
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
            foreach ($H in ($global:TriageUserHives | Where-Object ProfilePath)) {
                foreach ($Rel in $Map.Keys) {
                    Get-FolderFiles -Folder (Join-Path -Path $H.ProfilePath -ChildPath $Rel) -DestBase "Users\$( $H.Sid )\$( $Map[$Rel] )"
                }
            }
        }
        BrowserDatabases = {
            $Wanted = @{
                Chromium = "History", "Favicons", "Shortcuts", "Top Sites", "Web Data", "Network\Cookies", "Cookies"
                Firefox  = "places.sqlite", "cookies.sqlite", "formhistory.sqlite", "favicons.sqlite"
            }
            foreach ($H in ($global:TriageUserHives | Where-Object ProfilePath)) {
                foreach ($B in (Get-TriageConfig -Key "Browsers")) {
                    $Root = Join-Path -Path $H.ProfilePath -ChildPath $B.Root
                    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { continue }
                    foreach ($P in (Get-ChildItem -LiteralPath $Root -Directory -Force -ErrorAction SilentlyContinue)) {
                        foreach ($F in $Wanted[$B.Type]) {
                            foreach ($Sfx in "", "-wal", "-journal") {
                                $Src = Join-Path -Path $P.FullName -ChildPath "$F$Sfx"
                                if (Test-Path -LiteralPath $Src -PathType Leaf) {
                                    [pscustomobject]@{
                                        Kind = "File"
                                        Source = $Src
                                        Dest = "Browsers\$( $H.Sid )\$( $B.Name )\$( $P.Name )\$F$Sfx"
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
            foreach ($H in ($global:TriageUserHives | Where-Object ProfilePath)) {
                Get-FolderFiles -Folder (Join-Path -Path $H.ProfilePath -ChildPath "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup") -DestBase "Startup\$( $H.Sid )"
            }
        }
        WmiRepository = { Get-FolderFiles -Folder "$SysRoot\System32\wbem\Repository" -DestBase "WMI_Repository" }
        Bits          = { Get-FolderFiles -Folder "$env:ProgramData\Microsoft\Network\Downloader" -DestBase "BITS" }
        WindowsUpdate = {
            Get-FolderFiles -Folder "$SysRoot\Logs\WindowsUpdate" -DestBase "WindowsUpdate" -Filter "*.etl"
            [pscustomobject]@{
                Kind   = "File"
                Source = "$SysRoot\SoftwareDistribution\ReportingEvents.log"
                Dest   = "WindowsUpdate\ReportingEvents.log"
            }
        }
        Defender = {
            $Def = "$env:ProgramData\Microsoft\Windows Defender"
            [pscustomobject]@{
                Kind   = "Folder"
                Source = "$Def\Quarantine"
                Dest   = "Defender\Quarantine"
            }
            [pscustomobject]@{
                Kind   = "Folder"
                Source = "$Def\Scans\History"
                Dest   = "Defender\ScanHistory"
            }
        }
        # Single quotes matter: in double quotes PowerShell would expand $MFT and $J as variables
        Mft = {
            [pscustomobject]@{
                Kind   = "Raw"
                Source = ('{0}\$MFT' -f $SysDrive)
                Dest   = "NTFS\MFT"
            }
        }
        UsnJrnl = {
            [pscustomobject]@{
                Kind   = "Raw"
                Source = ('{0}\$Extend\$UsnJrnl:$J' -f $SysDrive)
                Dest   = "NTFS\UsnJrnl_J"
            }
        }
    }

    foreach ($Set in $Cfg.Enabled) {
        if (-not $Sets.Contains($Set)) {
            Show-Message -Message "Unknown raw artifact set '$Set' in the configuration file." -Level WARNING -AddToLog
            continue
        }
        if ($Set -in $Cfg.LargeSets -and $FreeGb -lt $Cfg.MinFreeGbForLargeSets) {
            Show-Message -Message "Skipping '$Set' => only $( [int]$FreeGb ) GB free (minimum $( $Cfg.MinFreeGbForLargeSets ) GB)." -Level WARNING -AddToLog
            continue
        }

        Invoke-TriageTask -Message "Copying raw artifacts => $Set..." -Action {
            $Rows = foreach ($Item in @(& $Sets[$Set])) {
                $Dest = Join-Path -Path $RawFolder -ChildPath $Item.Dest
                $R = switch ($Item.Kind) {
                    'File'    { Copy-TriageFile -Source $Item.Source -Destination $Dest }
                    'Raw'     { Copy-TriageRawFile -Source $Item.Source -Destination $Dest }
                    'RegSave' { Save-TriageRegistryHive -HiveKey $Item.Source -Destination $Dest }
                    'Folder'  { Copy-TriageFolderBackup -Source $Item.Source -Destination $Dest }
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