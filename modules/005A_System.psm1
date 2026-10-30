#? ----------------------------------------
#? DISABLED DURING TESTING
#? WILL RE-ENABLE WHEN DONE
#?
#? Should test each function individually
#? ----------------------------------------


# $ExecutableFileTypes = (Get-TriageConfig -Key "ExecutableFileTypes")


function Get-LinkFiles {
    param(
        [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "link_files.txt")
    )
    $Data = Get-CimInstance -ClassName Win32_ShortcutFile |
            Select-Object FileName, Caption, @{ Name = "CreationDate"; Expression = { $_.ConvertToDateTime($_.CreationDate) } }, @{ Name = "LastAccessed"; Expression = { $_.ConvertToDateTime($_.LastAccessed) } }, @{ Name = "LastModified"; Expression = { $_.ConvertToDateTime($_.LastModified) } }, Target |
            Where-Object { $_.lastModified -gt ((Get-Date).AddDays(-20)) } |
            Sort-Object LastModified -Descending
    Write-OutputToFile -Data $Data -OutputFile $TxtFile
}


function Get-CompressedFiles {
    param(
        [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "compressed_files.txt")
    )
    $Data = Get-ChildItem -LiteralPath $env:SystemDrive -Recurse -Force -Include $ExecutableFileTypes |
            Where-Object { $_.Attributes -band [IO.FileAttributes]::Compressed }
    Write-OutputToFile -Data $Data -OutputFile $TxtFile
}


function Get-EncryptedFiles {
    param(
        [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "encrypted_files.txt")
    )
    $Data = Get-ChildItem -LiteralPath $env:SystemDrive -Recurse -Force -Include $ExecutableFileTypes |
            Where-Object { $_.Attributes -band [IO.FileAttributes]::Encrypted }
    Write-OutputToFile -Data $Data -OutputFile $TxtFile
}


function Get-TimelineOfExecutables {
    param(
        [string]$TxtFile = (Join-Path -Path $SystemFolder -ChildPath "timeline_of_executables.txt")
    )
    $Data = Get-ChildItem -LiteralPath $env:SystemDrive -Recurse -Force -Include $ExecutableFileTypes |
            Where-Object { -Not $_.PSIsContainer -and $_.LastWriteTime -gt ((Get-Date).AddDays(-10)) } |
            Select-Object FullName, LastWriteTime, @{N = "Owner"; E = { ($_ | Get-ACL).Owner } } |
            Sort-Object LastWriteTime -Desc
    Write-OutputToFile -Data $Data -OutputFile $TxtFile
}
