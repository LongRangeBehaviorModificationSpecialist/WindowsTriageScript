#? =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
#? DISABLED DURING TESTING
#? WILL RE-ENABLE WHEN DONE
#?
#? Should test each function individually
#? =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+


function Get-LinkFiles {

    param(
        [string]$output_file = "$system_folder\link_files.txt"
    )

    try {
        $FuncName = $($MyInvocation.MyCommand.Name)
        $Msg = "Listing Link Files (Last 20 Days)..."

        Show-Message -Msg $Msg

        $Command = { Get-CimInstance -ClassName Win32_ShortcutFile | Select-Object FileName, Caption, @{N = "CreationDate"; E = { $_.ConvertToDateTime($_.CreationDate) } }, @{N = "LastAccessed"; E = { $_.ConvertToDateTime($_.LastAccessed) } }, @{N = "LastModified"; E = { $_.ConvertToDateTime($_.LastModified) } }, Target | Where-Object { $_.lastModified -gt ((Get-Date).AddDays(-20)) } | Sort-Object LastModified -Descending }
        $data = &($command)

        Write-OutputToFile -Command $Command -Data $Data -OutputFile $output_file

        Show-OutputSavedMsgAndWriteLogEntry -File $output_file -FuncName $FuncName -LineNumber $(Get-LineNum)
    }
    catch {
        Show-WarningMsgAndWriteLogEntry -FuncName $FuncName -LineNumber $(Get-LineNum) -Msg "An error occured while running this function: $($_.Exception.Message)" -ErrorMsg
    }
}


function Get-CompressedFiles {

    param(
        [string]$output_file = "$system_folder\compressed_files.txt"
    )

    try {
        $FuncName = $($MyInvocation.MyCommand.Name)
        $Msg = "Listing Compressed Files..."

        Show-Message -Msg $Msg

        $Command = { Get-ChildItem -Path C:\ -Recurse -Force -Include $executable_file_types | Where-Object { $_.Attributes -band [IO.FileAttributes]::Compressed } }
        $data = &($command)

        Write-OutputToFile -Command $Command -Data $Data -OutputFile $output_file

        Show-OutputSavedMsgAndWriteLogEntry -File $output_file -FuncName $FuncName -LineNumber $(Get-LineNum)
    }
    catch {
        Show-WarningMsgAndWriteLogEntry -FuncName $FuncName -LineNumber $(Get-LineNum) -Msg "An error occured while running this function: $($_.Exception.Message)" -ErrorMsg
    }
}


function Get-EncryptedFiles {

    param(
        [string]$output_file = "$system_folder\encrypted_files.txt"
    )

    try {
        $FuncName = $($MyInvocation.MyCommand.Name)
        $Msg = "Listing Encrypted Files..."

        Show-Message -Msg $Msg

        $Command = { Get-ChildItem -Path C:\ -Recurse -Force -Include $executable_file_types | Where-Object { $_.Attributes -band [IO.FileAttributes]::Encrypted } }
        $data = &($command)

        Write-OutputToFile -Command $Command -Data $Data -OutputFile $output_file

        Show-OutputSavedMsgAndWriteLogEntry -File $output_file -FuncName $FuncName -LineNumber $(Get-LineNum)
    }
    catch {
        Show-WarningMsgAndWriteLogEntry -FuncName $FuncName -LineNumber $(Get-LineNum) -Msg "An error occured while running this function: $($_.Exception.Message)" -ErrorMsg
    }
}


function Get-TimelineOfExecutables {

    param(
        [string]$output_file = "$system_folder\timeline_of_executables.txt"
    )

    try {
        $FuncName = $($MyInvocation.MyCommand.Name)
        $Msg = "Getting Timeline of Executables..."

        Show-Message -Msg $Msg

        $Command = { Get-ChildItem -Path C:\ -Recurse -Force -include $executable_file_types | Where-Object { -Not $_.PSIsContainer -and $_.LastWriteTime -gt ((Get-Date).AddDays(-10)) } | Select-Object FullName, LastWriteTime, @{N = "Owner"; E = { ($_ | Get-ACL).Owner } } | Sort-Object LastWriteTime -Desc }
        $data = &($command)

        Write-OutputToFile -Command $Command -Data $Data -OutputFile $output_file

        Show-OutputSavedMsgAndWriteLogEntry -File $output_file -FuncName $FuncName -LineNumber $(Get-LineNum)
    }
    catch {
        Show-WarningMsgAndWriteLogEntry -FuncName $FuncName -LineNumber $(Get-LineNum) -Msg "An error occured while running this function: $($_.Exception.Message)" -ErrorMsg
    }
}


function Get-DownloadedExecutables {

    param(
        [string]$output_file = "$system_folder\downloaded_executables.txt"
    )

    try {
        $FuncName = $($MyInvocation.MyCommand.Name)
        $Msg = "Listing Downloaded Executable Files..."

        Show-Message -Msg $Msg

        $Command = { Get-ChildItem -Path C:\ -Recurse -Force -include $executable_file_types | ForEach-Object { $P = $_.FullName; Get-Item $P -Stream * } | Where-Object { $_.Stream -match "Zone.Identifier" } | Select-Object filename, stream, @{ N = "LastWriteTime"; E = { (Get-ChildItem $P).LastWriteTime } } }
        $data = &($command)

        Write-OutputToFile -Command $Command -Data $Data -OutputFile $output_file

        Show-OutputSavedMsgAndWriteLogEntry -File $output_file -FuncName $FuncName -LineNumber $(Get-LineNum)
    }
    catch {
        Show-WarningMsgAndWriteLogEntry -FuncName $FuncName -LineNumber $(Get-LineNum) -Msg "An error occured while running this function: $($_.Exception.Message)" -ErrorMsg
    }
}