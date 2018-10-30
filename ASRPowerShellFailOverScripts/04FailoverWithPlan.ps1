#04 =================================

#region Create Variables

    Import-Module -Name "C:\Users\MyVM\Desktop\DMSASRTemplateV1.1\01ASRvaultCreation.ps1"
    $hcname =getConstants
    $RPName=$hcname.RPName 
    #$GetAsrplan = Get-AzureRmRecoveryServicesAsrRecoveryPlan -Name $RPName

#endregion

#region Creates an ASR recovery plan   
  
    $ReplicationProtectedItem = Get-ASRReplicationProtectedItem  -ProtectionContainer $PrimaryProtContainer 
   # $hcname =getConstants
   # $RPName=$hcname.RPName 
    $GetAsrplan = Get-AzureRmRecoveryServicesAsrRecoveryPlan -Name $RPName -ErrorVariable notPresent -ErrorAction SilentlyContinue 
     if ($notPresent){
    $GetAsrplan = New-AzureRmRecoveryServicesAsrRecoveryPlan -Name $RPName -PrimaryFabric $PrimaryFabric -RecoveryFabric $RecoveryFabric -ReplicationProtectedItem $ReplicationProtectedItem}

#endregion

#region  Failover the virtual machine to a specific recovery point.
    
    #Start the failover job
    $Job_Failover = Start-ASRUnplannedFailoverJob -RecoveryPlan $GetAsrplan -Direction PrimaryToRecovery #-RecoveryPoint $RecoveryPoints[-1]

        do {
                $Job_Failover = Get-ASRJob -Job $Job_Failover;
                sleep 30;
        } while (($Job_Failover.State -eq "InProgress") -or ($JobFailover.State -eq "NotStarted"))

        $Job_Failover.State 
        Write-Output  $hcname.WriteOutputmsg
   
#endregion

#region Starts the commit failover action for a Site Recovery object.

    Start-AzureRmRecoveryServicesAsrCommitFailoverJob -RecoveryPlan $GetAsrplan
   
#endregion