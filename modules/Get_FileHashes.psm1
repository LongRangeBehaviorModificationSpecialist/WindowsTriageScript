function Get-FileHashes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ResultsFolder,
        [string[]]$ExcludedFiles = @(
            "*PowerShell_transcript*",
            "*Hash_Values*"
        ),
        [Parameter(Mandatory = $false)][string]$LogFile
    )

    begin {
        $Stopwatch    = [System.Diagnostics.Stopwatch]::StartNew()
        $ComputerName = $env:computername
    }

    process {
        try {
            $BeginMsg = "Hashing triage files for computer => $ComputerName"
            Show-Message -Message $BeginMsg -Level INFO -AddToLog

            $HashResultsFolder = Join-Path -Path $ResultsFolder -ChildPath "Hash_Results"
            $null = New-Item -ItemType Directory -Path $HashResultsFolder -Force

            $FolderCreatedMsg = "### '$HashResultsFolder' sub-directory created successfully ###"
            Show-Message -Message $FolderCreatedMsg -Level INFO -AddToLog

            $HashResultsFolderName = (Get-Item -Path $ResultsFolder).Name

            $HashFileSuffix = "hash_values.csv"
            $ResultsFile = "$($HashResultsFolderName)_$($HashFileSuffix)"

            # Add the filename and filetype to the end
            $HashResultsFilePath = Join-Path -Path $HashResultsFolder -ChildPath $ResultsFile

            $FileCreatedMsg = "The '$HashResultsFilePath' file was created successfully."
            Show-Message -Message $FileCreatedMsg -Level INFO -AddToLog

            # Get the hash values of all the saved files in the output directory
            $Results = @()

            # Exclude the PowerShell transcript file from being included in the
            # file that are hashed
            $FileToHash = Get-ChildItem -Path $ResultsFolder -Recurse -Force -File | Where-Object {
                foreach ($Pattern in $ExcludedFiles) {
                    if ($File.Name -like $Pattern) {
                        return $false
                    }
                }
                return $true
            }

            foreach ($File in $FileToHash) {
                $FileMd5HashValue = (Get-FileHash -Algorithm MD5 -Path $File.FullName).Hash

                $FileSha256HashValue = (Get-FileHash -Algorithm SHA256 -Path $File.FullName).Hash

                # Show & log $ProgressMsg message
                $ProgressMsg = "Hashing file => '$( $File.Name )'"
                Show-Message -Message $ProgressMsg -Level INFO -AddToLog

                $Results += [PSCustomObject]@{
                    # DirectoryName      = Split-Path $File.DirectoryName -Leaf
                    DirectoryName      = $File.DirectoryName
                    Name               = $File.Name
                    Extension          = $File.Extension
                    PSIsContainer      = $File.PSIsContainer
                    SizeInKB           = [math]::Round(($File.Length / 1KB), 2)
                    Mode               = $File.Mode
                    "FileHash(MD5)"    = $FileMd5HashValue
                    "FileHash(Sha256)" = $FileSha256HashValue
                    Attributes         = $File.Attributes
                    IsReadOnly         = $File.IsReadOnly
                    CreationTimeUTC    = $File.CreationTimeUtc
                    LastAccessTimeUTC  = $File.LastAccessTimeUtc
                    LastWriteTimeUTC   = $File.LastWriteTimeUtc
                }

                $HashFileMsg = "Completed hashing file: '$( $File.Name )' [SHA256: $( $FileSha256HashValue )]"
                Show-Message -Message $HashFileMsg -Level INFO -AddToLog
            }

            if ($Results.Count -gt 0) {
                # Export the results to the CSV file
                $Results | Export-Csv -Path $HashResultsFilePath -NoTypeInformation -Encoding UTF8
            }

            $ExecutionTime = $Stopwatch.Elapsed.TotalSeconds
            $HashResultsFileName = [System.IO.Path]::GetFileName($HashResultsFilePath)

            Show-Message -File $HashResultsFileName -ExecutionTime "$ExecutionTime seconds" -Level SUCCESS -AddToLog
        }
        catch {
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )' on $( $ComputerName ). Error => $( $_.Exception.Message )"
            Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
        }
    }
    end {
        if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    }
}
