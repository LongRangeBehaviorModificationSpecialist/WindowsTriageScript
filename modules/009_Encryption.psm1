function Get-TriageEncryptionData {
    [CmdletBinding()]
    param(
        [string]$EncryptionFolder
    )

    function Get-BitlockerInfoAndRecoveryKeys {
        param(
            [string]$OutputFile = "$EncryptionFolder\bitlocker_encryption.txt"
        )
        $Command = { Get-BitLockerVolume |
                Select-Object -Property * |
                Sort-Object MountPoint }
        $Data = &($Command)
        Write-OutputToFile -Command $Command -Data $Data -OutputFile $OutputFile

        function Search-BitlockerVolumes {
            # Recovery passwords stay in the main output file
            $KeyFile = $OutputFile
            # Get all BitLocker-protected drives on the computer
            $Volumes = $Data
            # Iterate through each drive
            foreach ($Vol in $Volumes) {
                $DriveLetter      = $Vol.MountPoint
                $ProtectionStatus = $Vol.ProtectionStatus
                $LockStatus       = $Vol.LockStatus
                $RecoveryKey      = $Vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }

                # Write output based on the protection status of each drive
                # `$ProtectionStatus -eq "On" -and `
                if ($null -ne $RecoveryKey) {
                    foreach ($K in @($RecoveryKey)) {
                        # The password goes to the output file ONLY
                        Add-Content -LiteralPath $KeyFile -Encoding UTF8 -Value "Drive $DriveLetter => ProtectorId => $( $K.KeyProtectorId ) => RecoveryPassword => $( $K.RecoveryPassword )"
                        # Console and log get the protector ID, which is not secret
                        Show-Message -Message "Drive $DriveLetter => recovery password saved to => $( Split-Path $KeyFile -Leaf ) (protector ID $( $K.KeyProtectorId ))" -Level INFO -AddToLog
                    }

                    $Data1 = "Drive $DriveLetter => Recovery Key => $( $RecoveryKey.RecoveryPassword )"
                    Write-OutputToFile -Data $Data1 -OutputFile $OutputFile -Append
                    Show-Message -Message $Data1 -Level INFO -AddToLog
                }
                elseif ($ProtectionStatus -eq "Unknown" -and $LockStatus -eq "Locked") {
                    $Data1 = "Drive $DriveLetter => This drive is mounted on the system, but IT IS NOT decrypted"
                    Write-OutputToFile -Data $Data1 -OutputFile $OutputFile -Append
                    Show-Message -Message $Data1 -Level INFO -AddToLog
                }
                else {
                    $Data1 = "Drive $DriveLetter => Does not have a recovery key or is not protected by BitLocker"
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

    $Tasks = @(
        @{
            Action  = { Get-BitlockerInfoAndRecoveryKeys }
            Message = "Getting BitLocker & Encryption Data and Recovery Keys (if applicable)..."
            Files   = "bitlocker_encryption.txt"
        }
    )

    Invoke-TriageTaskList -Tasks $Tasks -Folder $EncryptionFolder
}
