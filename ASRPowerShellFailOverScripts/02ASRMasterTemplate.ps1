
# 00 ===============================

#region Log in to your Microsoft Azure subscription

   # Login-AzureRmAccount

#endregion


# 01 =============================== 

#region Get details of the virtual machine

    $csv = Import-Csv -LiteralPath 'C:\Users\MyVM\Desktop\DMSASRTemplateV1.0\ASRVMDetails.csv'
    Import-Module -Name "C:\Users\MyVM\Desktop\DMSASRTemplateV1.0\ASRvaultCreation.ps1"

    for ($index = 0; $index -lt $csv.Length; $index++)
    { 
        # Get details of the virtual machine
        $VM = Get-AzureRmVM -ResourceGroupName $csv[$index].SourceVMResouceGroup -Name $csv[$index].SourceVMName

        #Get disk details for the disks of the virtual machine. Disk details will be used later when starting replication for the virtual machine.
        $OSDiskVhdURI = $VM.StorageProfile.OsDisk.Vhd.Uri
       # $DataDisk1VhdURI = $VM.StorageProfile.DataDisks[0].Vhd.Uri

#endregion

#region Create a Recovery Services vault.

    if($index-eq 0){
    fncreateVault}
    $PrimaryFabric = Get-AsrFabric -Name $hcname.PrimaryASRfabric_Name
    $RecoveryFabric = Get-AsrFabric -Name $hcname.RecoveryASRJob_Name
    $PrimaryProtContainer = Get-ASRProtectionContainer -Fabric $PrimaryFabric -Name $hcname.PContainerASRJob_Name
    $RecoveryProtContainer = Get-ASRProtectionContainer -Fabric $RecoveryFabric -Name $hcname.RContainerASRJob_Name
    $ReplicationPolicy = Get-ASRPolicy -Name $hcname.PolicyASRJob_Name
    $SourceToTargetPCMapping = Get-ASRProtectionContainerMapping -ProtectionContainer $PrimaryProtContainer -Name $hcname.ProtectionContainerMapping_Name
    $TargetToSourcePCMapping = Get-ASRProtectionContainerMapping -ProtectionContainer $RecoveryProtContainer -Name $hcname.ProtectionContainerFailover_Name

#endregion

#region Create storage accounts to replicate virtual machines to

    #Create Target storage account in the recovery region. In this case a Standard Storage account
    $TargetStorageAccount = Get-AzureRmStorageAccount -Name $csv[$index].TargetStorageAccountName -ResourceGroupName $csv[$index].TargetVMResouceGroup -ErrorAction Ignore
    if ($TargetStorageAccount.StorageAccountName -ne $csv[$index].TargetStorageAccountName)  
        {    
            $TargetStorageAccount = New-AzureRmStorageAccount -Name $csv[$index].TargetStorageAccountName -ResourceGroupName $csv[$index].TargetVMResouceGroup -Location $csv[$index].TargetVMLocation -SkuName Standard_LRS -Kind Storage
        }
      
    #Create Cache storage account for replication logs in the primary region
    $CacheStorageAccount = Get-AzureRmStorageAccount -Name $csv[$index].TargetCacheStorageAccountName -ResourceGroupName $csv[$index].SourceVMResouceGroup -ErrorAction Ignore
        if ($CacheStorageAccount.StorageAccountName -ne $csv[$index].TargetCacheStorageAccountName)  
        {    
            $CacheStorageAccount = New-AzureRmStorageAccount -Name $csv[$index].TargetCacheStorageAccountName -ResourceGroupName $csv[$index].SourceVMResouceGroup -Location $csv[$index].SourceVMLocation -SkuName Standard_LRS -Kind Storage
        }

#endregion 

#region Create network mappings.

     #region Create an Azure virtual network in the recovery region to failover to

         #Create a Recovery Network in the recovery region
         $TargetRecoveryVnet = Get-AzureRmVirtualNetwork -Name $csv[$index].TragetVNetName -ResourceGroupName $csv[$index].TargetVMResouceGroup -ErrorVariable notPresent -ErrorAction SilentlyContinue 
         if ($notPresent){
         $TargetRecoveryVnet = New-AzureRmVirtualNetwork -Name $csv[$index].TragetVNetName -ResourceGroupName $csv[$index].TargetVMResouceGroup -Location $csv[$index].TargetVMLocation -AddressPrefix $csv[$index].AddressPrefixVnet
         Add-AzureRmVirtualNetworkSubnetConfig -Name $csv[$index].TragetSubnetName -VirtualNetwork $TargetRecoveryVnet -AddressPrefix $csv[$index].AddressPrefixSubnet | Set-AzureRmVirtualNetwork
         }
         $TargetRecoveryNetwork = $TargetRecoveryVnet.Id

     #endregion


     #region Retrieve the virtual network that the virtual machine is connected to

         #Get first network interface card(nic) of the virtual machine
         $SplitNicArmId = $VM.NetworkProfile.NetworkInterfaces[0].Id.split("/")

         #Extract resource group name from the ResourceId of the nic
         $NICRG = $SplitNicArmId[4]

         #Extract resource name from the ResourceId of the nic
         $NICname = $SplitNicArmId[-1]

         #Get network interface details using the extracted resource group name and resourec name
         $NIC = Get-AzureRmNetworkInterface -ResourceGroupName $NICRG -Name $NICname

         #Get the subnet ID of the subnet that the nic is connected to
         $PrimarySubnet = $NIC.IpConfigurations[0].Subnet

         # Extract the resource ID of the Azure virtual network the nic is connected to from the subnet ID
         $SourcePrimaryNetwork = (Split-Path(Split-Path($PrimarySubnet.Id))).Replace("\","/")

     #endregion


     #region Create network mapping between the primary virtual network and the recovery virtual network
         
         # Create an ASR network mapping between the primary Azure virtual network and the recovery Azure virtual network
         $P2RnetASRJob = New-ASRNetworkMapping -AzureToAzure -Name $hcname.P2RnetASRJobName -PrimaryFabric $PrimaryFabric -PrimaryAzureNetworkId $SourcePrimaryNetwork -RecoveryFabric $RecoveryFabric -RecoveryAzureNetworkId $TargetRecoveryNetwork

         #Track Job status to check for completion
         while (($P2RnetASRJob.State -eq "InProgress") -or ($P2RnetASRJob.State -eq "NotStarted")){ 
                 sleep 10; 
                 $P2RnetASRJob = Get-ASRJob -Job $P2RnetASRJob
                 }
         if($P2RnetASRJob.State -eq $hcname.WOmsgSuccess){Write-Output  $hcname.WriteOutputmsg}
    
     #endregion


     #region Create network mapping for the reverse direction (failback)

         # Create an ASR network mapping for failback between the recovery Azure virtual network and the primary Azure virtual network
         $F2RnetASRJob = New-ASRNetworkMapping -AzureToAzure -Name $hcname.F2RnetASRJobName -PrimaryFabric $RecoveryFabric -PrimaryAzureNetworkId $TargetRecoveryNetwork -RecoveryFabric $PrimaryFabric -RecoveryAzureNetworkId $SourcePrimaryNetwork

         #Track Job status to check for completion
         while (($F2RnetASRJob.State -eq "InProgress") -or ($F2RnetASRJob.State -eq "NotStarted")){ 
                sleep 10; 
                $F2RnetASRJob = Get-ASRJob -Job $F2RnetASRJob
          }

          if($F2RnetASRJob.State -eq $hcname.WOmsgSuccess){Write-Output  $hcname.WriteOutputmsg}
    
     #endregion
 
#endregion

#region  Replicate Azure virtual machines to a recovery region for disaster recovery.
    
    #Specify replication properties for each disk of the VM that is to be replicated (create disk replication configuration)

    #Disk replication configuration for the OS disk
    $OSDiskReplicationConfig = New-AzureRmRecoveryServicesAsrAzureToAzureDiskReplicationConfig -VhdUri $OSDiskVhdURI -LogStorageAccountId $CacheStorageAccount.Id -RecoveryAzureStorageAccountId $TargetStorageAccount.Id

    $diskconfigs = @()
    $diskconfigs += $OSDiskReplicationConfig
    if ($VM.StorageProfile.DataDisks.Count -gt 0){
    for($dinndex=0;$dinndex -lt $VM.StorageProfile.DataDisks.Count;$dinndex++){
    
    $DataDisk1VhdURI = $VM.StorageProfile.DataDisks[$dinndex].Vhd.Uri
    
    #Disk replication configuration for data disk
    $DataDisk1ReplicationConfig = New-AzureRmRecoveryServicesAsrAzureToAzureDiskReplicationConfig -VhdUri $DataDisk1VhdURI -LogStorageAccountId $CacheStorageAccount.Id -RecoveryAzureStorageAccountId $TargetStorageAccount.Id
    

    #Create a list of disk replication configuration objects for the disks of the virtual machine that are to be replicated.
    $diskconfigs += $DataDisk1ReplicationConfig}}
    else{}

    #Get the resource group that the virtual machine must be created in when failed over.
    $RecoveryRG = Get-AzureRmResourceGroup -Name $csv[$index].TargetVMResouceGroup -Location $csv[$index].TargetVMLocation

    #Start replication by creating replication protected item. Using a GUID for the name of the replication protected item to ensure uniqueness of name.  
    $RPIASRJob = New-ASRReplicationProtectedItem -AzureToAzure -AzureVmId $VM.Id -Name (New-Guid).Guid -ProtectionContainerMapping $SourceToTargetPCMapping -AzureToAzureDiskReplicationConfiguration $diskconfigs -RecoveryResourceGroupId $RecoveryRG.ResourceId

    #Track Job status to check for completion
    while (($RPIASRJob.State -eq "InProgress") -or ($RPIASRJob.State -eq "NotStarted")){ 
            sleep 10; 
            $RPIASRJob = Get-ASRJob -Job $RPIASRJob
    }
    if($RPIASRJob.State -eq $hcname.WOmsgSuccess){Write-Output  $hcname.WriteOutputmsg}
}

    # Monitor the replication state and replication health for the virtual machine by getting details of the replication protected item corresponding to it....
    Get-ASRReplicationProtectedItem -ProtectionContainer $PrimaryProtContainer | Select FriendlyName, ProtectionState, ReplicationHealth,ProtectableItem

#endregion 
