function Get-TriagePrefetchData {
    [CmdletBinding()]
    param(
        [string]$PrefetchFolder
    )

    function Invoke-ScriptBlock {
        param(
            [scriptblock]$Action,
            [string]$FunctionMessage,
            [string]$OutputFile
        )
        try {
            Show-Message -Message $FunctionMessage -Level INFO -AddToLog
            & $Action
            Show-Message -File $OutputFile -Level SUCCESS -AddToLog
        }
        catch {
            Show-Message -Message "Execution failed during $( $MyInvocation.MyCommand.Name ).  Error => $( $_.Exception.Message )" -Level ERROR -AddToLog
        }
    }

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

    $PrefetchWorkFlow = [ordered]@{
        { Get-PrefetchFiles } = (
            "Getting Prefetch File Information...",
            "prefetch_files.csv"
        )
        { Get-RecentExecutions } = (
            "Gatting Recently Executed Files...",
            "recent_executions.csv"
        )
    }

    foreach ($Task in $PrefetchWorkFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $Task.Key -FunctionMessage $Task.Value[0] -OutputFile $Task.Value[1]
    }
}
