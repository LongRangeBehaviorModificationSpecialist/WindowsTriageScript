function Get-FileHashes {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [string]$ResultsFolder,

        [string[]]$ExcludedFiles = @("*PowerShell_transcript*", "*Hash_Values*")

        [Parameter(Mandatory = $false)]
        [string]$LogFile
    )

    begin {
        $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $ComputerName = $env:computername
    }

    process {
        try {
            $BeginMsg = "Hashing triage files for computer: $( $ComputerName )"
            Show-Message -Message $BeginMsg -Level INFO -AddToLog

            $HashResultsFolder = Join-Path -Path $ResultsFolder -ChildPath "Hash_Results"
            $null              = New-Item -ItemType Directory -Path $HashResultsFolder -Force

            Test-IfExists -FolderName $HashResultsFolder -Type FOLDER

            $HashResultsFolderName = (Get-Item -Path $ResultsFolder).Name

            # Add the filename and filetype to the end
            $HashResultsFilePath = Join-Path -Path $HashResultsFolder -ChildPath "${HashResultsFolderName}_hash_values.csv"

            Test-IfExists -FileName $HashResultsFilePath -Type FILE

            # Get the hash values of all the saved files in the output directory
            $Results = @()

            # Exclude the PowerShell transcript file from being included in the file that are hashed
            $FileToHash = Get-ChildItem -Path $ResultsFolder -Recurse -Force -File | Where-Object {
                foreach ($Pattern in $ExcludedFiles) {
                    if ($_.Name -like $Pattern) {
                        return $false
                    }
                }
                return $true
            }

            foreach ($File in $FileToHash) {
                $FileHashValue = (Get-FileHash -Algorithm SHA256 -Path $File.FullName).Hash

                # Show & log $ProgressMsg message
                $ProgressMsg = "Hashing file: '$( $File.Name )'"
                Show-Message -Message $ProgressMsg -Level INFO -AddToLog

                $Results += [PSCustomObject]@{
                    DirectoryName      = Split-Path $File.DirectoryName -Leaf
                    Name               = $File.Name
                    Extension          = $File.Extension
                    PSIsContainer      = $File.PSIsContainer
                    SizeInKB           = [math]::Round(($File.Length / 1KB), 2)
                    Mode               = $File.Mode
                    "FileHash(Sha256)" = $FileHashValue
                    Attributes         = $File.Attributes
                    IsReadOnly         = $File.IsReadOnly
                    CreationTimeUTC    = $File.CreationTimeUtc
                    LastAccessTimeUTC  = $File.LastAccessTimeUtc
                    LastWriteTimeUTC   = $File.LastWriteTimeUtc
                }

                $HashFileMsg = "Completed hashing file: '$( $_.Name )' [SHA256: $( $FileHashValue )]"
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
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )' on $( $ComputerName ). Error -> $( $_.Exception.Message )"
            Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
        }
    }
    end {
        if ($Stopwatch.IsRunning) {
            $Stopwatch.Stop()
        }
    }
}
