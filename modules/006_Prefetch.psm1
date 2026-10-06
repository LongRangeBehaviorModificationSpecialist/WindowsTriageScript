function Get-TriagePrefetchData {
    [CmdletBinding()]
    param(
        [string]$PrefetchFolder
    )

    function Get-PrefetchFiles {
        param(
            [string]$OutputFile = "$PrefetchFolder\prefetch_files.csv"
        )
        $Command = { Get-ChildItem -Path "$env:SystemRoot\Prefetch\*.pf" |
                        Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }

    function Get-RecentExecutions {
        param(
            [string]$OutputFile = "$PrefetchFolder\recent_executions.csv"
        )
        $Folders = @("$env:SystemDrive\Temp")
        foreach ($U in $global:TriageUserHives) {
            $Folders += Join-Path -Path $U.ProfilePath -ChildPath "AppData\Roaming"
            $Folders += Join-Path -Path $U.ProfilePath -ChildPath "AppData\Local\Temp"
        }

        $Data = foreach ($F in $Folders) {
            if (-not (Test-Path -LiteralPath $F)) { continue }
            Get-ChildItem -LiteralPath $F -Recurse -Force -ErrorAction SilentlyContinue |
                Select-Object FullName, Length, Attributes, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
        }
        Write-OutputToCsv -Data ($Data | Sort-Object LastAccessTimeUtc -Descending) -OutputFile $OutputFile
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
