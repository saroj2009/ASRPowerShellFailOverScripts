
#region constants

    $cname = Import-CSV -Path "C:\Users\MyVM\Desktop\DMSASRTemplateV1.0\ConfigFile.csv"
    $hcname=@{}
    function getConstants 
        {
            $hcname2=@{}
            foreach($index in $cname)
            {
                $hcname2[$index.Name]=$index.Value
            }
            return $hcname2
        }
    $hcname =getConstants
    $createVault = fncreateVault
#endregion

#region Create a Recovery Services vault

    function fncreateVault
    {

        #Create a resource group for the recovery services vault in the recovery Azure region
        Get-AzureRmResourceGroup -Name $hcname.VaultTargetVMResouceGroupName -Location $hcname.VaultTargetVMLocation -ErrorVariable notPresent -ErrorAction SilentlyContinue 
        if ($notPresent){
        New-AzureRmResourceGroup -Name $hcname.VaultTargetVMResouceGroupName -Location $hcname.VaultTargetVMLocation}


        #Create a new Recovery services vault in the recovery region
        $vault = New-AzureRmRecoveryServicesVault -Name $hcname.ASRRecoveryVaultName -ResourceGroupName $hcname.VaultTargetVMResouceGroupName -Location $hcname.VaultTargetVMLocation


        #Download the vault settings file for the vault.
        $Vaultsettingsfile = Get-AzureRmRecoveryServicesVaultSettingsFile -Vault $vault -SiteRecovery -Path $hcname.VaultsettingsfilePath


        #Import the downloaded vault settings file to set the vault context for the PowerShell session.
        Import-AzureRmRecoveryServicesAsrVaultSettingsFile -Path $Vaultsettingsfile.FilePath


        #Delete the downloaded vault settings file
        Remove-Item -Path $Vaultsettingsfile.FilePath
        fnvaultReplication
    }

#endregion 

#region Prepare the vault to start replicating Azure virtual machines

    function fnvaultReplication
    {

        #region 1.Create a Site Recovery fabric object to represent the primary(source) region

            #Create Primary ASR fabric
            $PrimaryASRJob = New-ASRFabric -Azure -Location $hcname.PrimaryASRfabric_Location  -Name $hcname.PrimaryASRfabric_Name 


            # Track Job status to check for completion
            while (($PrimaryASRJob.State -eq "InProgress") -or ($PrimaryASRJob.State -eq "NotStarted")){ 
                    #If the job hasn't completed, sleep for 10 seconds before checking the job status again
                    sleep 10; 
                    $PrimaryASRJob = Get-ASRJob -Job $PrimaryASRJob}
            

            #Check if the Job completed successfully. The updated job state of a successfuly completed job should be "Succeeded"
            Write-Output $hcname.WOmsgCreatePrimaryASRfabric # $PrimaryASRJob.State

            $PrimaryFabric = Get-AsrFabric -Name $hcname.PrimaryASRfabric_Name

        #endregion


        #region 2. Create a Site Recovery fabric object to represent the recovery region

            #Create Recovery ASR fabric
            $RecoveryASRJob = New-ASRFabric -Azure -Location $hcname.RecoveryASRJob_Location  -Name $hcname.RecoveryASRJob_Name 


            # Track Job status to check for completion
            while (($RecoveryASRJob.State -eq "InProgress") -or ($RecoveryASRJob.State -eq "NotStarted")){ 
                    sleep 10; 
                    $RecoveryASRJob = Get-ASRJob -Job $RecoveryASRJob}


            #Check if the Job completed successfully. The updated job state of a successfuly completed job should be "Succeeded"
            Write-Output $hcname.WOmsgCreateRecoveryASRfabric #$RecoveryASRJob.State

            $RecoveryFabric = Get-AsrFabric -Name $hcname.RecoveryASRJob_Name

        #endregion


        #region 3. Create a Site Recovery protection container in the primary fabric

            #Create a Protection container in the primary Azure region (within the Primary fabric)
            $PContainerASRJob = New-AzureRmRecoveryServicesAsrProtectionContainer -InputObject $PrimaryFabric -Name $hcname.PContainerASRJob_Name

            #Track Job status to check for completion
            while (($PContainerASRJob.State -eq "InProgress") -or ($PContainerASRJob.State -eq "NotStarted")){ 
                    sleep 10; 
                    $PContainerASRJob = Get-ASRJob -Job $PContainerASRJob}


            Write-Output $hcname.WOmsgCreateProtectioncontainerInPrimaryAzureRegion #$PContainerASRJob.State

            $PrimaryProtContainer = Get-ASRProtectionContainer -Fabric $PrimaryFabric -Name $hcname.PContainerASRJob_Name

        #endregion


        #region 4. Create a Site Recovery protection container in the recovery fabric

            #Create a Protection container in the recovery Azure region (within the Recovery fabric)
            $RContainerASRJob = New-AzureRmRecoveryServicesAsrProtectionContainer -InputObject $RecoveryFabric -Name $hcname.RContainerASRJob_Name


            #Track Job status to check for completion
            while (($RContainerASRJob.State -eq "InProgress") -or ($RContainerASRJob.State -eq "NotStarted")){ 
                    sleep 10; 
                    $RContainerASRJob = Get-ASRJob -Job $RContainerASRJob}


            #Check if the Job completed successfully. The updated job state of a successfuly completed job should be "Succeeded"
            Write-Output $hcname.WOmsgCreateProtectioncontainerInRecoveryAzureRegion #$RContainerASRJob.State

            $RecoveryProtContainer = Get-ASRProtectionContainer -Fabric $RecoveryFabric -Name $hcname.RContainerASRJob_Name

        #endregion


        #region 5. Create a replication policy

            #Create replication policy
            $PolicyASRJob = New-ASRPolicy -AzureToAzure -Name $hcname.PolicyASRJob_Name -RecoveryPointRetentionInHours 24 -ApplicationConsistentSnapshotFrequencyInHours 1


            #Track Job status to check for completion
            while (($PolicyASRJob.State -eq "InProgress") -or ($PolicyASRJob.State -eq "NotStarted")){ 
                    sleep 10; 
                    $PolicyASRJob = Get-ASRJob -Job $PolicyASRJob}


            #Check if the Job completed successfully. The updated job state of a successfuly completed job should be "Succeeded"
            Write-Output $hcname.WOmsgCreateReplicationPolicy #$PolicyASRJob.State

            $ReplicationPolicy = Get-ASRPolicy -Name $hcname.PolicyASRJob_Name

        #endregion


        #region 6. Create a protection container mapping between the primary and recovery protection container

            #Create Protection container mapping between the Primary and Recovery Protection Containers with the Replication policy
            $PContainerASRJob2 = New-ASRProtectionContainerMapping -Name $hcname.ProtectionContainerMapping_Name -Policy $ReplicationPolicy -PrimaryProtectionContainer $PrimaryProtContainer -RecoveryProtectionContainer $RecoveryProtContainer


            #Track Job status to check for completion
            while (($PContainerASRJob2.State -eq "InProgress") -or ($PContainerASRJob2.State -eq "NotStarted")){ 
                    sleep 10; 
                    $PContainerASRJob2 = Get-ASRJob -Job $PContainerASRJob2}


            #Check if the Job completed successfully. The updated job state of a successfuly completed job should be "Succeeded"
            Write-Output $hcname.WOmsgPrimaryContainerMappingForPrimaryAndRecovery  # $PContainerASRJob2.State

            $SourceToTargetPCMapping = Get-ASRProtectionContainerMapping -ProtectionContainer $PrimaryProtContainer -Name $hcname.ProtectionContainerMapping_Name

        #endregion


        #region 7. Create a protection container mapping for failback (reverse replication after a failover)

            #Create Protection container mapping (for failback) between the Recovery and Primary Protection Containers with the Replication policy 
            $PContainerASRJob3 = New-ASRProtectionContainerMapping -Name $hcname.ProtectionContainerFailover_Name -Policy $ReplicationPolicy -PrimaryProtectionContainer $RecoveryProtContainer -RecoveryProtectionContainer $PrimaryProtContainer


            #Track Job status to check for completion
            while (($PContainerASRJob3.State -eq "InProgress") -or ($PContainerASRJob3.State -eq "NotStarted")){ 
                    sleep 10; 
                    $PContainerASRJob3 = Get-ASRJob -Job $PContainerASRJob3
                    }


            #Check if the Job completed successfully. The updated job state of a successfuly completed job should be "Succeeded"
            Write-Output $hcname.WOmsgCreateProtectioncontainerMappingForFailover  #$PContainerASRJob3.State

            $TargetToSourcePCMapping = Get-ASRProtectionContainerMapping -ProtectionContainer $RecoveryProtContainer -Name $hcname.ProtectionContainerFailover_Name

        #endregion

    }

#endregion

