function Get-FileHashes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$resultsFolder,

        [string[]]$excludedFiles = @("*PowerShell_transcript*", "*Hash_Values*")
    )

    begin {
        $stopwatch    = [System.Diagnostics.Stopwatch]::StartNew()
        $computerName = $env:computername
    }
    process {
        try {
            $beginMessage = "Hashing triage files for computer: $computerName"
            Show-MessageAndWriteLogEntry -Message $beginMessage -Level INFO

            $hashResultsFolder  = Join-Path -Path $resultsFolder -ChildPath "Hash_Results"
            $null = New-Item -ItemType Directory -Path $hashResultsFolder  -Force

            Test-IfExists -FolderName $hashResultsFolder -Type FOLDER

            # Add the filename and filetype to the end
            $hashResultsFilePath = Join-Path -Path $hashResultsFolder -ChildPath "$((Get-Item -Path $resultsFolder).Name)_hash_values.csv"
            $null = New-Item -ItemType File -Path $hashResultsFilePath -Force

            $hashResultsFileName = [System.IO.Path]::GetFileName($hashResultsFilePath)

            Test-IfExists -FileName $hashResultsFilePath -Type FILE

            # Get the hash values of all the saved files in the output directory
            $results = @()

            # Exclude the PowerShell transcript file from being included in the file that are hashed
            $results = Get-ChildItem -Path $resultsFolder -Recurse -Force -File | Where-Object {
                $fileName = $_.Name

                foreach ($entry in $excludedFiles) {

                    if ($fileName -like $entry) {
                        return $false
                    }
                }
            } | ForEach-Object {
                $fileHash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash
                [PSCustomObject]@{
                    DirectoryName      = $(Split-Path $_.DirectoryName -Leaf)
                    Name               = $_.Name
                    # BaseName           = $_.BaseName
                    # Extension          = $_.Extension
                    PSIsContainer      = $_.PSIsContainer
                    SizeInKB           = [math]::Round(($_.Length / 1KB), 2)
                    Mode               = $_.Mode
                    "FileHash(Sha256)" = $fileHash
                    Attributes         = $_.Attributes
                    IsReadOnly         = $_.IsReadOnly
                    CreationTimeUTC    = $_.CreationTimeUtc
                    LastAccessTimeUTC  = $_.LastAccessTimeUtc
                    LastWriteTimeUTC   = $_.LastWriteTimeUtc
                }

                # Show & log $progressMsg message
                $progressMsg = "Hashing file: '$($_.Name)'"
                Show-MessageAndWriteLogEntry -Message $progressMsg -Level INFO

                $hashMsgFile = "Completed hashing file: '$($_.Name)' [SHA256: $($fileHash)]"
                Show-MessageAndWriteLogEntry -Message $hashMsgFile -Level INFO
            }

            # Export the results to the CSV file
            $results | Export-Csv -Path $hashResultsFilePath -NoTypeInformation -Encoding UTF8

            $currentExecutionTime = $stopwatch.Elapsed.TotalSeconds

            Show-MessageAndWriteLogEntry -File $hashResultsFileName -ExecutionTime "$currentExecutionTime seconds" -Level SUCCESS

            $stopwatch.Stop()
        }
        catch {
            $errorMessage = "Execution failed during '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
            Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
        }
    }
    end {
        if ($stopwatch.IsRunning) {
            $stopwatch.Stop()
        }
    }
}
