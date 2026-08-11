function Get-FileHashes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsFolder,

        [string[]]$ExcludedFiles = @("*PowerShell_transcript*", "*Hash_Values*")
    )

    begin {
        $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $ComputerName = $env:computername
    }
    process {
        try {
            $BeginMsg = "Hashing triage files for computer: $( $ComputerName )"
            Show-MessageAndWriteLogEntry -Msg $BeginMsg -Level INFO

            $HashResultsFolder = Join-Path -Path $ResultsFolder -ChildPath "Hash_Results"
            $null = New-Item -ItemType Directory -Path $HashResultsFolder  -Force

            Test-IfExists -FolderName $HashResultsFolder -Type FOLDER

            # Add the filename and filetype to the end
            $HashResultsFilePath = Join-Path -Path $HashResultsFolder -ChildPath "$((Get-Item -Path $ResultsFolder).Name)_hash_values.csv"
            $null = New-Item -ItemType File -Path $HashResultsFilePath -Force

            $HashResultsFileName = [System.IO.Path]::GetFileName($HashResultsFilePath)

            Test-IfExists -FileName $HashResultsFilePath -Type FILE

            # Get the hash values of all the saved files in the output directory
            $Results = @()

            # Exclude the PowerShell transcript file from being included in the file that are hashed
            $Results = Get-ChildItem -Path $ResultsFolder -Recurse -Force -File | Where-Object {
                $FileName = $_.Name

                foreach ($Entry in $Excluded_Files) {

                    if ($FileName -like $Entry) {
                        return $false
                    }
                }
            } | ForEach-Object {
                $FileHashValue = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash
                [PSCustomObject]@{
                    DirectoryName      = $(Split-Path $_.DirectoryName -Leaf)
                    Name               = $_.Name
                    Extension          = $_.Extension
                    PSIsContainer      = $_.PSIsContainer
                    SizeInKB           = [math]::Round(($_.Length / 1KB), 2)
                    Mode               = $_.Mode
                    "FileHash(Sha256)" = $FileHashValue
                    Attributes         = $_.Attributes
                    IsReadOnly         = $_.IsReadOnly
                    CreationTimeUTC    = $_.CreationTimeUtc
                    LastAccessTimeUTC  = $_.LastAccessTimeUtc
                    LastWriteTimeUTC   = $_.LastWriteTimeUtc
                }

                # Show & log $ProgressMsg message
                $ProgressMsg = "Hashing file: '$( $_.Name )'"
                Show-MessageAndWriteLogEntry -Msg $ProgressMsg -Level INFO

                $HashFileMsg = "Completed hashing file: '$( $_.Name )' [SHA256: $( $FileHashValue )]"
                Show-MessageAndWriteLogEntry -Msg $HashFileMsg -Level INFO
            }

            # Export the results to the CSV file
            $Results | Export-Csv -Path $HashResultsFilePath -NoTypeInformation -Encoding UTF8

            $ExecutionTime = $Stopwatch.Elapsed.TotalSeconds

            Show-MessageAndWriteLogEntry -File $HashResultsFileName -ExecutionTime "$( $ExecutionTime ) seconds" -Level SUCCESS

            $Stopwatch.Stop()
        }
        catch {
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error: $( $_.Exception.Message )"
            Show-MessageAndWriteLogEntry -Msg $ErrorMsg -Level ERROR
        }
    }
    end {
        if ($Stopwatch.IsRunning) {
            $Stopwatch.Stop()
        }
    }
}
