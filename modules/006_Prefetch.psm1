function Get-TriagePrefetchData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PrefetchFolder
    )


    # 06.01
    function Get-PrefetchFiles {
        param([string]$OutputFile)

        $Data = Get-ChildItem -Path "$env:SystemRoot\Prefetch\*.pf" |
            Select-Object -Property *
        Write-OutputToCsv -Data $Data -OutputFile $OutputFile
    }


    # 06.02
    function Get-RecentExecutions {
        param([string]$OutputFile)

        $Folders = @("$env:SystemDrive\Temp")
        foreach ($User in $global:TriageUserHives) {
            if (-not $User.ProfilePath) {
                continue
            }
            $Folders += Join-Path -Path $User.ProfilePath -ChildPath "AppData\Roaming"
            $Folders += Join-Path -Path $User.ProfilePath -ChildPath "AppData\Local\Temp"
        }

        $Data = foreach ($Folder in $Folders) {
            if (-not (Test-Path -LiteralPath $Folder)) {
                continue
            }
            Get-ChildItem -LiteralPath $Folder -Recurse -Depth 3 -Force `
                -ErrorAction SilentlyContinue |
                Select-Object FullName, Length, Attributes, CreationTimeUtc,
                LastWriteTimeUtc, LastAccessTimeUtc
        }
        Write-OutputToCsv -Data ($Data | Sort-Object LastAccessTimeUtc -Descending) -OutputFile $OutputFile
    }

    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $Tasks = @(
        @{
            Action  = { param($Paths) Get-PrefetchFiles -OutputFile $Paths[0] }
            Message = "06.01_Getting Prefetch File Information..."
            Files   = "06.01_prefetch_files.csv"
        }
        @{
            Action  = { param($Paths) Get-RecentExecutions -OutputFile $Paths[0] }
            Message = "06.02_Getting Recently Executed Files..."
            Files   = "06.02_recent_executions.csv"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $PrefetchFolder

}
