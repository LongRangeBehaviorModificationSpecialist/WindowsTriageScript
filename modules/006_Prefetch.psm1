function Get-TriagePrefetchData {
    [CmdletBinding()]
    param(
        [string]$prefetchFolder
    )


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$action,
            [string]$functionMsg,
            [string]$outputFile
        )
        try {
            Show-MessageAndWriteLogEntry -Message $functionMsg -Level INFO
            & $action
            Show-MessageAndWriteLogEntry -File $outputFile -Level SUCCESS
        }
        catch {
            $errorMessage = "Execution failed during '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
            Show-MessageAndWriteLogEntry -Message $errorMessage -Level ERROR
        }
    }


    function Get-PrefetchFiles {
        param(
            [string]$csvOutputFile = "$prefetchFolder\prefetch_files.csv"
        )
        $command =  { Get-ChildItem -Path "C:\Windows\Prefetch\*.pf" |
                        Select-Object -Property *
                    }
        $data = &($command)
        Write-OutputToCsv -Data $data -OutputFile $csvOutputFile
    }


    function Get-RecentExecutions {
        param(
            [string]$outputFile = "$prefetchFolder\recent_executions.txt"
        )
        $foldersToCheck = @(
            "$env:TEMP",
            "$env:USERPROFILE\AppData\Roaming",
            "$env:USERPROFILE\AppData\Local\Temp"
        )
        $command = { foreach ($folder in $foldersToCheck) {
                        Get-ChildItem -Path $folder -Recurse |
                        Select-Object -Property * |
                        Sort-Object LastAccessTime -Descending
                    } }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $workFlow = [ordered]@{
        { Get-PrefetchFiles } = (
            "Getting Prefetch File Information...",
            "prefetch_files.csv"
        )
        { Get-RecentExecutions } = (
            "Gatting Recently Executed Files...",
            "recent_executions.txt"
        )
    }

    foreach ($task in $workFlow.GetEnumerator())
    {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
