function Get-TriagePrefetchData
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PrefetchFolder
    )

    begin
    {
        function Get-PrefetchFiles
        {
            param(
                [string]$CsvFile = (Join-Path -Path $PrefetchFolder -ChildPath "06.01_prefetch_files.csv")
            )

            $Data = Get-ChildItem -Path "$env:SystemRoot\Prefetch\*.pf" |
                Select-Object -Property *
            Write-OutputToCsv -Data $Data -OutputFile $CsvFile
        }

        function Get-RecentExecutions
        {
            param(
                [string]$CsvFile = (Join-Path -Path $PrefetchFolder -ChildPath "06.02_recent_executions.csv")
            )

            $Folders = @("$env:SystemDrive\Temp")
            foreach ($User in $global:TriageUserHives)
            {
                $Folders += Join-Path -Path $User.ProfilePath -ChildPath "AppData\Roaming"
                $Folders += Join-Path -Path $User.ProfilePath -ChildPath "AppData\Local\Temp"
            }

            $Data = foreach ($Folder in $Folders)
            {
                if (-not (Test-Path -LiteralPath $Folder))
                {
                    continue
                }
                Get-ChildItem -LiteralPath $Folder -Recurse -Force -ErrorAction SilentlyContinue |
                    Select-Object FullName, Length, Attributes, CreationTimeUtc, LastWriteTimeUtc,
                    LastAccessTimeUtc
            }
            Write-OutputToCsv -Data ($Data | Sort-Object LastAccessTimeUtc -Descending) -OutputFile $CsvFile
        }
    }
    process
    {
        # ----------------------------------
        # Run the functions from the module
        # ----------------------------------
        $Tasks = @(
            @{
                Action  = { Get-PrefetchFiles }
                Message = "06.01_Getting Prefetch File Information..."
                Files   = "06.01_prefetch_files.csv"
            }
            @{
                Action  = { Get-RecentExecutions }
                Message = "06.02_Getting Recently Executed Files..."
                Files   = "06.02_recent_executions.csv"
            }
        )
        Invoke-TriageTaskList -Tasks $Tasks -Folder $PrefetchFolder
    }
}
