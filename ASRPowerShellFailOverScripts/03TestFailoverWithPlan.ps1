# 02 ================================

#region Create Variable

    Import-Module -Name "C:\Users\MyVM\Desktop\DMSASRTemplateV1.0\ASRvaultCreation.ps1"
    $PrimaryProtContainer = Get-ASRProtectionContainer -Fabric $PrimaryFabric -Name $hcname.PContainerASRJob_Name
    $PrimaryFabric = Get-AsrFabric -Name $hcname.PrimaryASRfabric_Name
    $RecoveryFabric = Get-AsrFabric -Name $hcname.RecoveryASRJob_Name

#endregion

#region Creates an ASR recovery plan   
  
    $ReplicationProtectedItem = Get-ASRReplicationProtectedItem  -ProtectionContainer $PrimaryProtContainer 
    $hcname =getConstants
    $RPName=$hcname.RPName 
    $Asrplan = New-AzureRmRecoveryServicesAsrRecoveryPlan -Name $RPName -PrimaryFabric $PrimaryFabric -RecoveryFabric $RecoveryFabric -ReplicationProtectedItem $ReplicationProtectedItem
    $GetAsrplan = Get-AzureRmRecoveryServicesAsrRecoveryPlan -Name $RPName

#endregion


# 03 ================================

#region TestFailover

    #Create a seperate network for test failover (not connected to my DR network)
    $TFOVnet = New-AzureRmVirtualNetwork -Name $hcname.TFOVnetName -ResourceGroupName $hcname.TFOResourceGroupName -Location $hcname.TFOLocation -AddressPrefix $hcname.TFOAddressPrefix
    Add-AzureRmVirtualNetworkSubnetConfig -Name $hcname.TFOSubnetName -VirtualNetwork $TFOVnet -AddressPrefix $hcname.TFOSubnetAddressPrefix | Set-AzureRmVirtualNetwork
    $TFONetwork= $TFOVnet.Id
   
    $TFOJob = Start-ASRTestFailoverJob -RecoveryPlan $GetAsrplan -AzureVMNetworkId $TFONetwork  -Direction PrimaryToRecovery

    Get-ASRJob -Job $TFOJob
    Write-Output  $hcname.WriteOutputmsg

#endregion

#region Once testing is complete on the test failed over virtual machine, clean up the test copy by starting the cleanup test failover operation. 

    $Job_TFOCleanup = Start-ASRTestFailoverCleanupJob -RecoveryPlan $GetAsrplan

    Get-ASRJob -Job $Job_TFOCleanup | Select State
    Write-Output  $hcname.WriteOutputmsg

#endregion

