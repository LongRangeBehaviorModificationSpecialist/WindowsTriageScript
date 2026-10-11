function Get-TriagePrefetchData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PrefetchFolder
    )

    function Get-PrefetchFiles {
        param(
            [string]$CsvFile = (Join-Path -Path $PrefetchFolder -ChildPath "prefetch_files.csv")
        )
        $Command = { Get-ChildItem -Path "$env:SystemRoot\Prefetch\*.pf" | Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $CsvFile
    }

    function Get-RecentExecutions {
        param(
            [string]$OutputFile = (Join-Path -Path $PrefetchFolder -ChildPath "recent_executions.csv")
        )
        $Folders = @("$env:SystemDrive\Temp")
        foreach ($User in $global:TriageUserHives) {
            $Folders += Join-Path -Path $User.ProfilePath -ChildPath "AppData\Roaming"
            $Folders += Join-Path -Path $User.ProfilePath -ChildPath "AppData\Local\Temp"
        }

        $Data = foreach ($Folder in $Folders) {
            if (-not (Test-Path -LiteralPath $Folder)) {
                continue
            }
            Get-ChildItem -LiteralPath $Folder -Recurse -Force -ErrorAction SilentlyContinue | Select-Object FullName, Length, Attributes, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
        }
        Write-OutputToCsv -Data ($Data | Sort-Object LastAccessTimeUtc -Descending) -OutputFile $CsvFile
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $Tasks = @(
        @{
            Action  = { Get-PrefetchFiles }
            Message = "Getting Prefetch File Information..."
            Files   = "prefetch_files.csv"
        }
        @{
            Action  = { Get-RecentExecutions }
            Message = "Getting Recently Executed Files..."
            Files   = "recent_executions.csv"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $PrefetchFolder
}
