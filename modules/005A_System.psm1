#? =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
#? DISABLED DURING TESTING
#? WILL RE-ENABLE WHEN DONE
#?
#? Should test each function individually
#? =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+


# $ExecutableFileTypes = (Get-TriageConfig -Key "ExecutableFileTypes")


function Get-LinkFiles {
    param(
        [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "link_files.txt")
    )
    # $Msg = "Listing Link Files (Last 20 Days)..."

    $Command = { Get-CimInstance -ClassName Win32_ShortcutFile | Select-Object FileName, Caption, @{ N = "CreationDate"; E = { $_.ConvertToDateTime($_.CreationDate) } }, @{ N = "LastAccessed"; E = { $_.ConvertToDateTime($_.LastAccessed) } }, @{ N = "LastModified"; E = { $_.ConvertToDateTime($_.LastModified) } }, Target | Where-Object { $_.lastModified -gt ((Get-Date).AddDays(-20)) } | Sort-Object LastModified -Descending }
    $Data = &($Command)

    Write-OutputToFile -Data $Data -OutputFile $TxtFile
}


function Get-CompressedFiles {
    param(
        [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "compressed_files.txt")
    )
    # $Msg = "Listing Compressed Files..."

    $Command = { Get-ChildItem -LiteralPath $env:SystemDrive -Recurse -Force -Include $ExecutableFileTypes | Where-Object { $_.Attributes -band [IO.FileAttributes]::Compressed } }
    $Data = &($Command)

    Write-OutputToFile -Data $Data -OutputFile $TxtFile
}


function Get-EncryptedFiles {
    param(
        [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "encrypted_files.txt")
    )
    # $Msg = "Listing Encrypted Files..."

    $Command = { Get-ChildItem -LiteralPath $env:SystemDrive -Recurse -Force -Include $ExecutableFileTypes | Where-Object { $_.Attributes -band [IO.FileAttributes]::Encrypted } }
    $Data = &($Command)

    Write-OutputToFile -Data $Data -OutputFile $TxtFile
}


function Get-TimelineOfExecutables {
    param(
        [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "timeline_of_executables.txt")
    )
    # $Msg = "Getting Timeline of Executables..."

    $Command = { Get-ChildItem -LiteralPath $env:SystemDrive -Recurse -Force -include $ExecutableFileTypes | Where-Object { -Not $_.PSIsContainer -and $_.LastWriteTime -gt ((Get-Date).AddDays(-10)) } | Select-Object FullName, LastWriteTime, @{N = "Owner"; E = { ($_ | Get-ACL).Owner } } | Sort-Object LastWriteTime -Desc }
    $Data = &($Command)

    Write-OutputToFile -Data $Data -OutputFile $TxtFile
}


function Get-DownloadedExecutables {
    param(
        [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "downloaded_executables.txt")
    )
    # $Msg = "Listing Downloaded Executable Files..."

    $Command = { Get-ChildItem -LiteralPath $env:SystemDrive -Recurse -Force -include $ExecutableFileTypes | ForEach-Object { $P = $_.FullName; Get-Item $P -Stream * } | Where-Object { $_.Stream -match "Zone.Identifier" } | Select-Object filename, stream, @{ N = "LastWriteTime"; E = { (Get-ChildItem $P).LastWriteTime } } }
    $Data = &($Command)

    Write-OutputToFile -Data $Data -OutputFile $TxtFile
}
