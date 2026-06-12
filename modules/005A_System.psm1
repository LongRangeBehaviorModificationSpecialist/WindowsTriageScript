#? =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
#? DISABLED DURING TESTING
#? WILL RE-ENABLE WHEN DONE
#?
#? Should test each function individually
#? =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+


function Get-LinkFiles {

    param(
        [string]$OutputFile = "$SystemFolder\link_files.txt"
    )

    try {
        $FuncName = $($MyInvocation.MyCommand.Name)
        $Msg = "Listing Link Files (Last 20 Days)..."

        Show-Message -Message $Msg

        $Command = { Get-CimInstance -ClassName Win32_ShortcutFile | Select-Object FileName, Caption, @{N = "CreationDate"; E = { $_.ConvertToDateTime($_.CreationDate) } }, @{N = "LastAccessed"; E = { $_.ConvertToDateTime($_.LastAccessed) } }, @{N = "LastModified"; E = { $_.ConvertToDateTime($_.LastModified) } }, Target | Where-Object { $_.lastModified -gt ((Get-Date).AddDays(-20)) } | Sort-Object LastModified -Descending }
        $data = &($command)

        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile

        Show-OutputSavedMsgAndWriteLogEntry -File $OutputFile -FuncName $FuncName -LineNumber $(Get-LineNum)
    }
    catch {
        Show-WarningMsgAndWriteLogEntry -FuncName $FuncName -LineNumber $(Get-LineNum) -Message "An error occured while running this function: $($_.Exception.Message)" -ErrorMsg
    }
}


function Get-CompressedFiles {

    param(
        [string]$OutputFile = "$SystemFolder\compressed_files.txt"
    )

    try {
        $FuncName = $($MyInvocation.MyCommand.Name)
        $Msg = "Listing Compressed Files..."

        Show-Message -Message $Msg

        $Command = { Get-ChildItem -Path C:\ -Recurse -Force -Include $ExecutableFileTypes | Where-Object { $_.Attributes -band [IO.FileAttributes]::Compressed } }
        $data = &($command)

        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile

        Show-OutputSavedMsgAndWriteLogEntry -File $OutputFile -FuncName $FuncName -LineNumber $(Get-LineNum)
    }
    catch {
        Show-WarningMsgAndWriteLogEntry -FuncName $FuncName -LineNumber $(Get-LineNum) -Message "An error occured while running this function: $($_.Exception.Message)" -ErrorMsg
    }
}


function Get-EncryptedFiles {

    param(
        [string]$OutputFile = "$SystemFolder\encrypted_files.txt"
    )

    try {
        $FuncName = $($MyInvocation.MyCommand.Name)
        $Msg = "Listing Encrypted Files..."

        Show-Message -Message $Msg

        $Command = { Get-ChildItem -Path C:\ -Recurse -Force -Include $ExecutableFileTypes | Where-Object { $_.Attributes -band [IO.FileAttributes]::Encrypted } }
        $data = &($command)

        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile

        Show-OutputSavedMsgAndWriteLogEntry -File $OutputFile -FuncName $FuncName -LineNumber $(Get-LineNum)
    }
    catch {
        Show-WarningMsgAndWriteLogEntry -FuncName $FuncName -LineNumber $(Get-LineNum) -Message "An error occured while running this function: $($_.Exception.Message)" -ErrorMsg
    }
}


function Get-TimelineOfExecutables {

    param(
        [string]$OutputFile = "$SystemFolder\timeline_of_executables.txt"
    )

    try {
        $FuncName = $($MyInvocation.MyCommand.Name)
        $Msg = "Getting Timeline of Executables..."

        Show-Message -Message $Msg

        $Command = { Get-ChildItem -Path C:\ -Recurse -Force -include $ExecutableFileTypes | Where-Object { -Not $_.PSIsContainer -and $_.LastWriteTime -gt ((Get-Date).AddDays(-10)) } | Select-Object FullName, LastWriteTime, @{N = "Owner"; E = { ($_ | Get-ACL).Owner } } | Sort-Object LastWriteTime -Desc }
        $data = &($command)

        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile

        Show-OutputSavedMsgAndWriteLogEntry -File $OutputFile -FuncName $FuncName -LineNumber $(Get-LineNum)
    }
    catch {
        Show-WarningMsgAndWriteLogEntry -FuncName $FuncName -LineNumber $(Get-LineNum) -Message "An error occured while running this function: $($_.Exception.Message)" -ErrorMsg
    }
}


function Get-DownloadedExecutables {

    param(
        [string]$OutputFile = "$SystemFolder\downloaded_executables.txt"
    )

    try {
        $FuncName = $($MyInvocation.MyCommand.Name)
        $Msg = "Listing Downloaded Executable Files..."

        Show-Message -Message $Msg

        $Command = { Get-ChildItem -Path C:\ -Recurse -Force -include $ExecutableFileTypes | ForEach-Object { $P = $_.FullName; Get-Item $P -Stream * } | Where-Object { $_.Stream -match "Zone.Identifier" } | Select-Object filename, stream, @{ N = "LastWriteTime"; E = { (Get-ChildItem $P).LastWriteTime } } }
        $data = &($command)

        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile

        Show-OutputSavedMsgAndWriteLogEntry -File $OutputFile -FuncName $FuncName -LineNumber $(Get-LineNum)
    }
    catch {
        Show-WarningMsgAndWriteLogEntry -FuncName $FuncName -LineNumber $(Get-LineNum) -Message "An error occured while running this function: $($_.Exception.Message)" -ErrorMsg
    }
}