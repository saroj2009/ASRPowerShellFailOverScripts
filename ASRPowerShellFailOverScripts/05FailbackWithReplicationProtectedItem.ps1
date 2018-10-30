# 05 ================================

#region Create Variables

    Import-Module -Name "C:\Users\MyVM\Desktop\DMSASRTemplateV1.1\01ASRvaultCreation.ps1"
    $hcname =getConstants

#endregion

#region Updates the replication direction for the specified replication protected item or recovery plan. Used to re-protect/reverse replicate a failed over replicated item or recovery plan.
   $ReplicationProtectedItem = Get-ASRReplicationProtectedItem  -ProtectionContainer $PrimaryProtContainer 
   $job = Update-AzureRmRecoveryServicesAsrProtectionDirection -AzureToAzure -LogStorageAccountId $hcname.LogStorageAccountId -ProtectionContainerMapping $TargetToSourcePCMapping -RecoveryAzureStorageAccountId $hcname.RecoveryAzureStorageAccountId -RecoveryResourceGroupId $hcname.RecoveryResourceGroupId -ReplicationProtectedItem $ReplicationProtectedItem #-RecoveryAvailabilitySetId $recoveryAVSetIdYtoX    


    $ReplicationProtectedItem = Get-ASRReplicationProtectedItem  -ProtectionContainer $RecoveryProtContainer
    for ($index = 0; $index -lt $ReplicationProtectedItem.Count; $index++)
        {
            $RecoveryPointsFailback = Get-ASRRecoveryPoint -ReplicationProtectedItem $ReplicationProtectedItem.GetValue($index)

            #The list of recovery points returned may not be sorted chronologically and will need to be sorted first, in order to be able to find the oldest or the latest recovery points for the virtual machine.
            "{0} {1}" -f $RecoveryPointsFailback[0].RecoveryPointType, $RecoveryPointsFailback[-1].RecoveryPointTime


            #Start the failback job
            $Job_Failback = Start-ASRUnplannedFailoverJob -ReplicationProtectedItem $ReplicationProtectedItem.GetValue($index) -Direction PrimaryToRecovery -RecoveryPoint $RecoveryPointsFailback[-1]


            do {
                    $Job_Failback = Get-ASRJob -Job $Job_Failback;
                    sleep 30;
            } while (($Job_Failback.State -eq "InProgress") -or ($Job_Failback.State -eq "NotStarted"))

            $Job_Failback.State
            Write-Output  $hcname.WriteOutputmsg
        }
#endregion
