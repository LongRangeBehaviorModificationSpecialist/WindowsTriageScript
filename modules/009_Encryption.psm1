function Get-TriageEncryptionData {
    [CmdletBinding()]

    param( [string]$EncryptionFolder )


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

    function Get-BitlockerInfoAndRecoveryKeys {
        param( [string]$OutputFile = "$EncryptionFolder\bitlocker_encryption.txt" )
        $Command = { Get-BitLockerVolume |
                        Select-Object -Property * |
                        Sort-Object MountPoint }
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
                    Show-Message -Message $Data1 -Level INFO -AddToLog
                }
                elseif ($ProtectionStatus -eq "Unknown" -and $LockStatus -eq "Locked") {
                    $Data1 = "Drive $DriveLetter This drive is mounted on the system, but IT IS NOT decrypted"
                    Write-OutputToFile -Data $Data1 -OutputFile $OutputFile -Append
                    Show-Message -Message $Data1 -Level INFO -AddToLog
                }
                else {
                    $Data1 = "Drive $DriveLetter Does not have a recovery key or is not protected by BitLocker"
                    Write-OutputToFile -Data $Data1 -OutputFile $OutputFile -Append
                    Show-Message -Message $Data1 -Level INFO -AddToLog
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
        Invoke-ScriptBlock -Action $Task.key -FunctionMessage $Task.value[0] -OutputFile $Task.value[1]
    }
}
