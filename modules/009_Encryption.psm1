function Get-TriageEncryptionData {
    [CmdletBinding()]
    param(
        [string]$encryption_folder
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


    function Get-BitlockerInfoAndRecoveryKeys {
        param(
            [string]$output_file = "$encryption_folder\bitlocker_encryption.txt"
        )
        $command =  { Get-BitLockerVolume |
                        Select-Object -Property * |
                        Sort-Object MountPoint
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $output_file

        function Search-BitlockerVolumes {
            # Get all BitLocker-protected drives on the computer
            $volumes = $data
            # Iterate through each drive
            foreach ($vol in $volumes) {
                $drive_letter = $vol.MountPoint
                $protection_status = $vol.ProtectionStatus
                $lock_status = $vol.LockStatus
                $recovery_key = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }

                # Write output based on the protection status of each drive
                if ($protection_status -eq "On" -and $null -ne $recovery_key) {
                    $data1 = "Drive $drive_letter -> Recovery Key: $($recovery_key.RecoveryPassword)"
                    Write-OutputToFile -Data $data1 -OutputFile $output_file -Append
                    Show-MessageAndWriteLogEntry -Msg $data1 -Level INFO
                }
                elseif ($protection_status -eq "Unknown" -and $lock_status -eq "Locked") {
                    $data1 = "Drive $drive_letter This drive is mounted on the system, but IT IS NOT decrypted"
                    Write-OutputToFile -Data $data1 -OutputFile $output_file -Append
                    Show-MessageAndWriteLogEntry -Msg $data1 -Level INFO
                }
                else {
                    $data1 = "Drive $drive_letter Does not have a recovery key or is not protected by BitLocker"
                    Write-OutputToFile -Data $data1 -OutputFile $output_file -Append
                    Show-MessageAndWriteLogEntry -Msg $data1 -Level INFO
                }
            }
        }
        Search-BitlockerVolumes
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $encryption_work_flow = [ordered]@{
        { Get-BitlockerInfoAndRecoveryKeys } = (
            "Getting BitLocker & Encryption Data and Recovery Keys (if applicable)...",
            "bitlocker_encryption.txt"
        )
    }

    foreach ($task in $encryption_work_flow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
