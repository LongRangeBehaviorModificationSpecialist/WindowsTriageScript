function Get-TriagePrefetchData {
    [CmdletBinding()]

    param([string]$PrefetchFolder)

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
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error -> $( $_.Exception.Message )"
            Show-Message -Message $ErrorMsg -Level ERROR -AddToLog
        }
    }

    function Get-PrefetchFiles {
        param([string]$CsvOutputFile = "$PrefetchFolder\prefetch_files.csv")
        $Command = { Get-ChildItem -Path "C:\Windows\Prefetch\*.pf" |
                        Select-Object -Property * }
        $Data = &($Command)
        Write-OutputToCsv -Data $Data -OutputFile $CsvOutputFile
    }

    function Get-RecentExecutions {
        param([string]$OutputFile = "$PrefetchFolder\recent_executions.txt")
        $FoldersToCheck = @(
            "$env:TEMP",
            "$env:USERPROFILE\AppData\Roaming",
            "$env:USERPROFILE\AppData\Local\Temp"
        )
        $Command = { foreach ($Folder in $FoldersToCheck) {
                        Get-ChildItem -Path $Folder -Recurse |
                        Select-Object -Property * |
                        Sort-Object LastAccessTime -Descending } }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile
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
            "recent_executions.txt"
        )
    }

    foreach ($Task in $PrefetchWorkFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $Task.key -FunctionMessage $Task.value[0] -OutputFile $Task.value[1]
    }
}
