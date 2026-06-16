function Get-TriageEncryptionData {
    [CmdletBinding()]
    param(
        [string]$encryptionFolder
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


    function Get-BitlockerInfoAndRecoveryKeys {
        param(
            [string]$outputFile = "$encryptionFolder\bitlocker_encryption.txt"
        )
        $command =  { Get-BitLockerVolume |
                        Select-Object -Property * |
                        Sort-Object MountPoint
                    }
        $data = &($command)
        Write-OutputToFile -Command $command -Data $data -OutputFile $outputFile

        function Search-BitlockerVolumes {
            # Get all BitLocker-protected drives on the computer
            $volumes = $data
            # Iterate through each drive
            foreach ($vol in $volumes) {
                $driveLetter = $vol.MountPoint
                $protectionStatus = $vol.ProtectionStatus
                $lockStatus = $vol.LockStatus
                $recoveryKey = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }

                # Write output based on the protection status of each drive
                if ($protectionStatus -eq "On" -and $null -ne $recoveryKey) {
                    $data1 = "Drive $driveLetter -> Recovery Key: $($recoveryKey.RecoveryPassword)"
                    Write-OutputToFile -Data $data1 -OutputFile $outputFile -Append
                    Show-MessageAndWriteLogEntry -Message $data1 -Level INFO
                }
                elseif ($protectionStatus -eq "Unknown" -and $lockStatus -eq "Locked") {
                    $data1 = "Drive $driveLetter This drive is mounted on the system, but IT IS NOT decrypted"
                    Write-OutputToFile -Data $data1 -OutputFile $outputFile -Append
                    Show-MessageAndWriteLogEntry -Message $data1 -Level INFO
                }
                else {
                    $data1 = "Drive $driveLetter Does not have a recovery key or is not protected by BitLocker"
                    Write-OutputToFile -Data $data1 -OutputFile $outputFile -Append
                    Show-MessageAndWriteLogEntry -Message $data1 -Level INFO
                }
            }
        }
        Search-BitlockerVolumes
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $workFlow = [ordered]@{
        { Get-BitlockerInfoAndRecoveryKeys } = (
            "Getting BitLocker & Encryption Data and Recovery Keys (if applicable)...",
            "bitlocker_encryption.txt"
        )
    }

    foreach ($task in $workFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $task.key -functionMsg $task.value[0] -OutputFile $task.value[1]
    }
}
