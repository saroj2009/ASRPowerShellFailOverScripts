
#region Login 
   # Login-AzureRmAccount
#endregion

#region Get all of the VM's using object and for loop: 
$TargetVMResouceGroup = "ASRAutomationRecovery-RG"
$TargetVMLocation = "North Central US"
$ASRRecoveryVaultName = "A2ARecoveryVault"
$RecoveryPlan = "ASRpolicy1"
$ASRPolicyName = "A2APolicy"
$TargetStorageAccountName = "a2atargetstorageaccount"
$TargetCacheStorageAccountName = "a2atargetcachestorage"
$AddressPrefixVnet = "192.168.0.0/24"
$AddressPrefixSubnet = "192.168.0.16/28"
   
   
    $rgname="ASRDemoRG"
    $rmvms=Get-AzurermVM -ResourceGroupName $rgname
    $VMlist=@()

   # Add info about VM's from the Resource Manager to the array 
    foreach ($vm in $rmvms) 
    {     
        # Get status (does not seem to be a property of $vm, so need to call Get-AzurevmVM for each rmVM) 
        $vmstatus = Get-AzurermVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Status  

        #Get the VM Info
        $nic = Get-AzureRmNetworkInterface -ResourceGroupName $vm.ResourceGroupName -Name $(Split-Path -Leaf $vm.NetworkProfile.NetworkInterfaces[0].Id)
                    
        $VM =$vm | where-object -Property Id -EQ $nic.VirtualMachine.id
        $VM_Resourcegroup = $($VM.ResourceGroupName)
      
        # $VM_Status = (($VMstatus | Where {$_.ResourceGroupName -eq $VM_Resourcegroup -and $_.Name -eq $VM_Name}).PowerState).Replace('VM ', '')
        $VM_IP =  ($nic.IpConfigurations | select-object -ExpandProperty PrivateIpAddress) -Join ';'
        $VMPIPName = ($nic.IpConfigurations.PublicIpAddress.Id -Split '/')[-1]
        $VM_PublicIP =  Get-AzureRmPublicIpAddress -Name $VMPIPName -ResourceGroupName $VM_Resourcegroup 
        $VM_PIP = $VM_PublicIP.IpAddress

        # Get information about network resources
        $NetworkInfo = Get-AzureRmVirtualNetwork -ResourceGroupName $VM_Resourcegroup
        $VNetName = $NetworkInfo.Name
        $Subnet = $NetworkInfo.Subnets
        
        #Uncomment this to check the values before going into the Array $VMINFO
        #Write-Output "$($VM.ResourceGroupName), $($VM.Name), $($VM.VMid), $($VM.Location), $VM_IP, $VM_PublicIP, $VM_IP_MAC, $VM_Alloc"
           
        # Add values to the array: 
        $VMobj = New-Object -TypeName PSObject  
        $VMobj | Add-Member -MemberType NoteProperty -Name SourceVMName -Value $vm.Name
        $VMobj | Add-Member -MemberType NoteProperty -Name SourceVMResouceGroup -Value $vm.ResourceGroupName   
        $VMobj | Add-Member -MemberType NoteProperty -Name SourceVMLocation -Value $vm.Location
        $VMobj | Add-Member -MemberType NoteProperty -Name TargetVMResouceGroup -Value $TargetVMResouceGroup
        $VMobj | Add-Member -MemberType NoteProperty -Name TargetVMLocation -Value $TargetVMLocation
        $VMobj | Add-Member -MemberType NoteProperty -Name ASRRecoveryVaultName -Value $ASRRecoveryVaultName
        $VMobj | Add-Member -MemberType NoteProperty -Name ASRRecoveryVaultResourceGroup -Value $TargetVMResouceGroup
        $VMobj | Add-Member -MemberType NoteProperty -Name RecoveryPlan -Value $RecoveryPlan
        $VMobj | Add-Member -MemberType NoteProperty -Name ASRPolicyName -Value $ASRPolicyName
        $VMobj | Add-Member -MemberType NoteProperty -Name TragetVNetName -Value $VNetName
        $VMobj | Add-Member -MemberType NoteProperty -Name TragetSubnetName -Value $Subnet[0].Name
        $VMobj | Add-Member -MemberType NoteProperty -Name TargetStorageAccountName -Value $TargetStorageAccountName
        $VMobj | Add-Member -MemberType NoteProperty -Name TargetCacheStorageAccountName -Value $TargetCacheStorageAccountName
        $VMobj | Add-Member -MemberType NoteProperty -Name AddressPrefixVnet -Value $AddressPrefixVnet
        $VMobj | Add-Member -MemberType NoteProperty -Name AddressPrefixSubnet -Value $AddressPrefixSubnet #$Subnet[0].AddressPrefix
       
        $VMlist+=$VMobj
    }

    #. $env:userprofile\Scripts\AzureRM\PS_AzureRM_Get_VMs.ps1

    $Project="DevOps"
    $clientFilePrefix="AzureRM"
    $clientFileCampaign="VMs"

    #Get Date Time
    $Date = ([DateTime]::Now).ToString("yyyyMMdd")
    $Time = ([DateTime]::Now).ToString("HHmmss")
    $DateStart=get-date

    #Change to Windows Path if running in Windows $env:USERPROFILE
    If ($($env:USERPROFILE)) {
    $fldrRoot="$($env:USERPROFILE)\"
    $fldrPathseparator='\'
    } Else {
    $fldrRoot="~/"
    $fldrPathseparator='/'
    }

    # Make Directory if not exist
    $fldrPath=$fldrRoot+"Documents"+$fldrPathseparator+$Project+$fldrPathseparator+$clientFilePrefix+$fldrPathseparator+$clientFileCampaign
    New-Item -ErrorAction Ignore -ItemType directory -Path $fldrPath

    #Make Imports Folder
    $fldrPathimports=$fldrPath+$fldrPathseparator+"Imports"
    New-Item -ErrorAction Ignore -ItemType directory -Path $fldrPathimports

    #Make Exports Folder Directory
    $fldrPathexports=$fldrPath+$fldrPathseparator+"Exports"
    New-Item -ErrorAction Ignore -ItemType directory -Path $fldrPathexports

    #Assign the variable to the export file Prefix
    #$VMInfo_Export=$fldrPathexports+$fldrPathseparator+$clientFilePrefix+"_"+$Project+"_"+$clientFileCampaign+"_"+$Date+"_"+$Time+".csv"
    $VMInfo_Export = "C:\Users\MyVM\Desktop\DMSASRTemplateV1.1\ASRVMDetails.csv"

    #$VMlist | Export-CSV -NoTypeInformation -Path C:\Users\MyVM\Desktop\servers.csv
    $VMlist | Export-CSV -NoTypeInformation -Path $VMInfo_Export  # C:\Users\MyVM\Documents\DevOps\AzureRM\VMs\Exports\AzureRM_DevOps_VMs_20181009_073019.csv


    #Depending on OS run the Open/Start command for the CSV Export
   # start $VMInfo_Export
   <# If ($OSTYPE -eq "LINUX") {open $VMInfo_Export} `
    ElseIf ($OSTYPE -eq "WINDOWS") {start $VMInfo_Export} `
    Else {Write-Host "Unknown OS"}#>

break
#endregion

   