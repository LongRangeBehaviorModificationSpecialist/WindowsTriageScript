function Get-TriageEncryptionData {
    [CmdletBinding()]
    param(
        [string]$EncryptionFolder
    )


    function Invoke-ScriptBlock {
        param(
            [scriptblock]$Action,
            [string]$FunctionMsg,
            [string]$OutputFile
        )
        try {
            Show-MessageAndWriteLogEntry -Msg $FunctionMsg -Level INFO
            & $Action
            Show-MessageAndWriteLogEntry -File $OutputFile -Level SUCCESS
        }
        catch {
            $ErrorMsg = "Execution failed during '$( $MyInvocation.MyCommand.Name )'. Error: $( $_.Exception.Message )"
            Show-MessageAndWriteLogEntry -Msg $ErrorMsg -Level ERROR
        }
    }


    function Get-BitlockerInfoAndRecoveryKeys {
        param(
            [string]$OutputFile = "$EncryptionFolder\bitlocker_encryption.txt"
        )
        $Command =  { Get-BitLockerVolume |
                        Select-Object -Property * |
                        Sort-Object MountPoint
                    }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile

        function Search-BitlockerVolumes {
            # Get all BitLocker-protected drives on the computer
            $Volumes = $Data
            # Iterate through each drive
            foreach ($Vol in $Volumes) {
                $DriveLetter      = $Vol.MountPoint
                $ProtectionStatus = $Vol.ProtectionStatus
                $LockStatus       = $Vol.LockStatus
                $RecoveryKey      = $Vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }

                # Write output based on the protection status of each drive
                if ($ProtectionStatus -eq "On" -and $null -ne $RecoveryKey) {
                    $Data1 = "Drive $DriveLetter -> Recovery Key: $($RecoveryKey.RecoveryPassword)"
                    Write-OutputToFile -Data $Data1 -OutputFile $OutputFile -Append
                    Show-MessageAndWriteLogEntry -Msg $Data1 -Level INFO
                }
                elseif ($ProtectionStatus -eq "Unknown" -and $LockStatus -eq "Locked") {
                    $Data1 = "Drive $DriveLetter This drive is mounted on the system, but IT IS NOT decrypted"
                    Write-OutputToFile -Data $Data1 -OutputFile $OutputFile -Append
                    Show-MessageAndWriteLogEntry -Msg $Data1 -Level INFO
                }
                else {
                    $Data1 = "Drive $DriveLetter Does not have a recovery key or is not protected by BitLocker"
                    Write-OutputToFile -Data $Data1 -OutputFile $OutputFile -Append
                    Show-MessageAndWriteLogEntry -Msg $Data1 -Level INFO
                }
            }
        }
        Search-BitlockerVolumes
    }


    # ----------------------------------
    # Run the functions from the module
    # ----------------------------------

    $EncryptionWorkFlow = [ordered]@{
        { Get-BitlockerInfoAndRecoveryKeys } = (
            "Getting BitLocker & Encryption Data and Recovery Keys (if applicable)...",
            "bitlocker_encryption.txt"
        )
    }

    foreach ($Task in $EncryptionWorkFlow.GetEnumerator()) {
        Invoke-ScriptBlock -Action $Task.key -functionMsg $Task.value[0] -OutputFile $Task.value[1]
    }
}
