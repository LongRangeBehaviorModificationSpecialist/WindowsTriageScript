function Get-FileHashes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$results_folder,

        [string[]]$excluded_files = @("*PowerShell_transcript*", "*Hash_Values*")
    )

    begin {
        $stopwatch    = [System.Diagnostics.Stopwatch]::StartNew()
        $computer_name = $env:computername
    }
    process {
        try {
            $begin_msg = "Hashing triage files for computer: $($computer_name)"
            Show-MessageAndWriteLogEntry -Msg $begin_msg -Level INFO

            $hash_results_folder  = Join-Path -Path $results_folder -ChildPath "Hash_Results"
            $null                 = New-Item -ItemType Directory -Path $hash_results_folder  -Force

            Test-IfExists -FolderName $hash_results_folder -Type FOLDER

            # Add the filename and filetype to the end
            $hash_results_file_path = Join-Path -Path $hash_results_folder -ChildPath "$((Get-Item -Path $results_folder).Name)_hash_values.csv"
            $null                   = New-Item -ItemType File -Path $hash_results_file_path -Force

            $hash_results_file_name = [System.IO.Path]::GetFileName($hash_results_file_path)

            Test-IfExists -FileName $hash_results_file_path -Type FILE

            # Get the hash values of all the saved files in the output directory
            $results = @()

            # Exclude the PowerShell transcript file from being included in the file that are hashed
            $results = Get-ChildItem -Path $results_folder -Recurse -Force -File | Where-Object {
                $file_name = $_.Name

                foreach ($entry in $excluded_files) {

                    if ($file_name -like $entry) {
                        return $false
                    }
                }
            } | ForEach-Object {
                $file_hash_value = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash
                [PSCustomObject]@{
                    DirectoryName      = $(Split-Path $_.DirectoryName -Leaf)
                    Name               = $_.Name
                    Extension          = $_.Extension
                    PSIsContainer      = $_.PSIsContainer
                    SizeInKB           = [math]::Round(($_.Length / 1KB), 2)
                    Mode               = $_.Mode
                    "FileHash(Sha256)" = $file_hash_value
                    Attributes         = $_.Attributes
                    IsReadOnly         = $_.IsReadOnly
                    CreationTimeUTC    = $_.CreationTimeUtc
                    LastAccessTimeUTC  = $_.LastAccessTimeUtc
                    LastWriteTimeUTC   = $_.LastWriteTimeUtc
                }

                # Show & log $progress_msg message
                $progress_msg = "Hashing file: `"$($_.Name)`""
                Show-MessageAndWriteLogEntry -Msg $progress_msg -Level INFO

                $hash_file_msg = "Completed hashing file: `"$($_.Name)`" [SHA256: $($file_hash_value)]"
                Show-MessageAndWriteLogEntry -Msg $hash_file_msg -Level INFO
            }

            # Export the results to the CSV file
            $results | Export-Csv -Path $hash_results_file_path -NoTypeInformation -Encoding UTF8

            $execution_time = $stopwatch.Elapsed.TotalSeconds

            Show-MessageAndWriteLogEntry -File $hash_results_file_name -ExecutionTime "$($execution_time) seconds" -Level SUCCESS

            $stopwatch.Stop()
        }
        catch {
            $error_msg = "Execution failed during `"$($MyInvocation.MyCommand.Name)`". Error: $($_.Exception.Message)"
            Show-MessageAndWriteLogEntry -Msg $error_msg -Level ERROR
        }
    }
    end {
        if ($stopwatch.IsRunning) {
            $stopwatch.Stop()
        }
    }
}
