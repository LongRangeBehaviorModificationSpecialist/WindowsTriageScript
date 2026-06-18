function Get-TriagePrefetchData {
    [CmdletBinding()]
    param(
        [string]$prefetch_folder
    )


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$action,
            [string]$function_msg,
            [string]$output_file
        )
        try {
            Show-MessageAndWriteLogEntry -Msg $function_msg -Level INFO
            & $action
            Show-MessageAndWriteLogEntry -File $output_file -Level SUCCESS
        }
        catch {
            $error_msg = "Execution failed during `"$($MyInvocation.MyCommand.Name)`". Error: $($_.Exception.Message)"
            Show-MessageAndWriteLogEntry -Msg $error_msg -Level ERROR
        }
    }


    function Get-PrefetchFiles {
        param(
            [string]$csv_output_file = "$prefetch_folder\prefetch_files.csv"
        )
        $command =  { Get-ChildItem -Path "C:\Windows\Prefetch\*.pf" |
                        Select-Object -Property *
                    }
        $data = &($command)
        Write-OutputToCsv -Data $data -OutputFile $csv_output_file
    }


    function Get-RecentExecutions {
        param(
            [string]$output_file = "$prefetch_folder\recent_executions.txt"
        )
        $folders_to_check = @(
            "$env:TEMP",
            "$env:USERPROFILE\AppData\Roaming",
            "$env:USERPROFILE\AppData\Local\Temp"
        )
        $command = { foreach ($folder in $folders_to_check) {
                        Get-ChildItem -Path $folder -Recurse |
                        Select-Object -Property * |
                        Sort-Object LastAccessTime -Descending
                    }
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $prefetch_work_flow = [ordered]@{
        { Get-PrefetchFiles } = (
            "Getting Prefetch File Information...",
            "prefetch_files.csv"
        )
        { Get-RecentExecutions } = (
            "Gatting Recently Executed Files...",
            "recent_executions.txt"
        )
    }

    foreach ($task in $prefetch_work_flow.GetEnumerator())
    {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
