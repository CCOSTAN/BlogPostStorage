#
#  Copyright © 2018, 2019, 2020 VMware Inc. All rights reserved.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of the software in this file (the "Software"), to deal in the Software 
#  without restriction, including without limitation the rights to use, copy, 
#  modify, merge, publish, distribute, sublicense, and/or sell copies of the 
#  Software, and to permit persons to whom the Software is furnished to do so, 
#  subject to the following conditions:
#  
#  The above copyright notice and this permission notice shall be included in 
#  all copies or substantial portions of the Software.
#  
#  The names "VMware" and "VMware, Inc." must not be used to endorse or promote 
#  products derived from the Software without the prior written permission of 
#  VMware, Inc.
#  
#  Products derived from the Software may not be called "VMware", nor may 
#  "VMware" appear in their name, without the prior written permission of 
#  VMware, Inc.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
#  VMWARE,INC. BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
#  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
#  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#

<#
    .SYNOPSIS
     Sample Powershell script to deploy a VMware UAG virtual appliance to Microsoft Azure.
    .EXAMPLE
     .\uagdeployeaz.ps1 uag1.ini 
#>

param([string]$iniFile = "uag.ini", [string] $rootPwd, [string] $adminPwd, [string] $ceipEnabled,
     [string] $awAPIServerPwd, [string] $awTunnelGatewayAPIServerPwd, [string] $awTunnelProxyAPIServerPwd, [string] $awCGAPIServerPwd, [string] $awSEGAPIServerPwd)

#
# Function to create an Azure Network Inteface Card (NIC)
#

function CreateNIC {
    Param ($settings, $nic)

    $virtualNetworkName = $settings.Azure.virtualNetworkName
    $subnetName = $settings.Azure.("subnetName"+$nic)
    $resourceGroupName = $settings.Azure.resourceGroupName
    $nicName = $settings.General.name+"-eth"+$nic
    $publicIPAddressName = $settings.Azure.("publicIPAddressName"+$nic)
    $networkSecurityGroupName = $settings.Azure.("networkSecurityGroupName"+$nic)

    $vnet = Get-AzureRmVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -ErrorAction Ignore -WarningAction SilentlyContinue

    if ($publicIPAddressName.length -gt 0) {
        $pip=Get-AzureRmPublicIpAddress -Name $publicIPAddressName -ResourceGroupName $resourceGroupName -ErrorAction Ignore -WarningAction SilentlyContinue
        $pipParam = @{
            "PublicIpAddressId"=$pip.Id
        }
    } else {
        $pipParam = @{}
    }

    if ($networkSecurityGroupName.length -gt 0) {
        $nsg=Get-AzureRmNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -ErrorAction Ignore -WarningAction SilentlyContinue
        $nsgParam = @{
            "NetworkSecurityGroupId"=$nsg.Id
        }
    } else {
        $nsgParam = @{}
    }

    $subnetId = $vnet.Subnets[0].Id

    if ($subnetName.Length -gt 0) {
        $sn = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet -ErrorAction Ignore -WarningAction SilentlyContinue
        if ($sn) {
            $subnetId = $sn.Id
        }
    }

    $newnic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $resourceGroupName -Location $settings.Azure.location -Force -SubnetId $subnetId @pipParam @nsgParam -WarningAction SilentlyContinue

    If([string]::IsNullOrEmpty($newnic)) {    
        $msg = $error[0]
        WriteErrorString "Error: Failed to create NIC$nic - $msg"
        Exit
    }

    $newnic
}

#
# Function to validate Azure network settings from values specified in the .INI file
#

function ValidateNetworkSettings {
    Param ($settings, $nic)

    $virtualNetworkName = $settings.Azure.virtualNetworkName
    $subnetName = $settings.Azure.("subnetName"+$nic)
    $resourceGroupName = $settings.Azure.resourceGroupName

    if ($virtualNetworkName.length -gt 0) {

        $vNet=Get-AzureRmVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -ErrorAction Ignore -WarningAction SilentlyContinue
        If([string]::IsNullOrEmpty($vNet)) {    
            $msg = $error[0]
            WriteErrorString "Error: [Azure] virtualNetworkName ($virtualNetworkName) not found"
            Exit
        }
    } else {
        WriteErrorString "Error: [Azure] virtualNetworkName not specified"
        Exit
    }

    if ($subnetName.Length -gt 0) {
        $sn = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet -ErrorAction Ignore -WarningAction SilentlyContinue
        if (!$sn) {
            WriteErrorString "Error: [Azure] subnetName$nic ($subnetName) not found in virtual network $virtualNetworkName"
            Exit
       }
    }

    $publicIPName = $settings.Azure.("publicIPAddressName"+$nic)

    if ($publicIPName.length -gt 0) {
    
        $pip=Get-AzureRmPublicIpAddress -Name $publicIPName -ResourceGroupName $resourceGroupName -ErrorAction Ignore -WarningAction SilentlyContinue
        If([string]::IsNullOrEmpty($pip)) {
            WriteErrorString "Error: [Azure] publicIPAddressName$nic ($publicIPName) not found"
            Exit
        }

        if ($pip.ipConfiguration.length -gt 0) {
            WriteErrorString "Error: [Azure] publicIPAddressName$nic ($publicIPName) is already in use"
            Exit
        }
    }

    $networkSecurityGroupName = $settings.Azure.("networkSecurityGroupName"+$nic)

    if ($networkSecurityGroupName.length -gt 0) {
        $nsg=Get-AzureRmNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -ErrorAction Ignore -WarningAction SilentlyContinue
        If([string]::IsNullOrEmpty($nsg)) {
            WriteErrorString "Error: [Azure] networkSecurityGroupName$nic ($networkSecurityGroupName) not found"
            Exit
        }
    }
}

#
# Generate pseudo random password that meets the required Azure complexity rules
#
 
function GenerateAzureRandomPassword {
    add-type -AssemblyName System.Web
    $pwd = [System.Web.Security.Membership]::GeneratePassword(12,3)
    $pwd = "Passw0rd!"+$pwd
    $pwd
}

function DeleteExistingUAGResources {
    Param ($settings, $uagName)

    $resourceGroupName = $settings.Azure.resourceGroupName
    $storageAccName = $settings.Azure.storageAccountName
    $diskStorageContainer = $settings.Azure.diskStorageContainer.ToLower()

    $storageContext = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -Contains $storageAccName}).Context

    $VMInfo = Get-AzureRmVM  -Name $uagName -ResourceGroupName $resourceGroupName -DisplayHint Expand -ErrorAction Ignore

    If ($VMInfo.Name) {

        write-host "Existing UAG VM $uagName and associated resources will be deleted"
	    $OsDiskUri = $VMInfo.StorageProfile.OsDisk.Vhd.Uri

        $resourceParams = @{
            'ResourceName' = $uagName
            'ResourceType' = 'Microsoft.Compute/virtualMachines'
            'ResourceGroupName' = $resourceGroupName
        }

        $vmResource = Get-AzureRmResource @resourceParams -ErrorAction Ignore

        if ($vmResource) {
            $vmId = $vmResource.Properties.VmId
            $diagContainerName = ('bootdiagnostics-{0}-{1}' -f $VMInfo.Name.ToLower(), $vmId)
        }

	    $rm = Remove-AzureRmVM -ResourceGroupName $resourceGroupName -Name $uagName -Force

        if ($rm) {
            $status = $rm.Status
	        write-host "Deleted UAG VM $uagName - Status=$status"
        }

        #
        #  Delete the VM's disk.
        #

	    if ($OsDiskUri) {
		    $OsDisk = Split-Path -Leaf $OsDiskUri
		    $out = Remove-AzureStorageBlob -Context $storageContext -Container $diskStorageContainer -Blob $OsDisk -Force -InformationAction Continue -ErrorAction Ignore

            $diskStorageContainer2 = Split-Path (split-path $OsDiskUri -Parent) -Leaf
            $out = Remove-AzureStorageBlob -Context $storageContext -Container $diskStorageContainer2 -Blob $OsDisk -Force -InformationAction Continue -ErrorAction Ignore
	    }

        #
        # Delete the boot diagnostics folder
        #

        if ($diagContainerName) {
            $out = Remove-AzureStorageContainer -Context $storageContext -Name $diagContainerName -Force
        }
    }

    #
    # Delete the NICs
    #

    $out = Remove-AzureRmNetworkInterface -ResourceGroupName $resourceGroupName -Name $($uagName+"-eth0")  –Force
    $out = Remove-AzureRmNetworkInterface -ResourceGroupName $resourceGroupName -Name $($uagName+"-eth1")  –Force
    $out = Remove-AzureRmNetworkInterface -ResourceGroupName $resourceGroupName -Name $($uagName+"-eth2")  –Force

}

#
# Load the dependent UAG PowerShell Module
#

$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir  = Split-Path -Parent $ScriptPath
$uagDeployModule=$ScriptDir+"\uagdeploy.psm1"

if (!(Test-path $uagDeployModule)) {
    Write-host "Error: PowerShell Module $uagDeployModule not found." -foregroundcolor red -backgroundcolor black
    Exit
}

import-module $uagDeployModule -Force -ArgumentList $awAPIServerPwd, $awTunnelGatewayAPIServerPwd, $awTunnelProxyAPIServerPwd, $awCGAPIServerPwd, $awSEGAPIServerPwd

#
# Check that the required Azure PowerShell modules are installed
#

if (-not (Get-Module -ListAvailable -Name "AzureRM.Compute")) {
    WriteErrorString "Error: Powershell module AzureRM.Compute not found. Run the command 'Install-Module -Name AzureRM -Force' and retry"
    Exit
}

if (-not (Get-Module -ListAvailable -Name "AzureRM.Storage")) {
    WriteErrorString "Error: Powershell module AzureRM.Storage not found. Run the command 'Install-Module -Name AzureRM -Force' and retry"
    Exit
}

if (-not (Get-Module -ListAvailable -Name "AzureRM.Profile")) {
    WriteErrorString "Error: Powershell module AzureRM.Profile not found. Run the command 'Install-Module -Name AzureRM -Force' and retry"
    Exit
}

Write-host "Unified Access Gateway (UAG) virtual appliance Microsoft Azure deployment script"

if (!(Test-path $iniFile)) {
    WriteErrorString "Error: Configuration file ($iniFile) not found."
    Exit
}

$settings = ImportIni $iniFile

$uagName=$settings.General.name

#
# Login if needed
#

Write-Host -NoNewline "Validating Azure subscription .."

try {
    $out=Get-AzureRmSubscription -ErrorAction Ignore
    }
    
catch {
    connect-AzurermAccount
}

Write-Host -NoNewline "."

if (!$out) {
    try {
        $out=Get-AzureRmSubscription -ErrorAction Ignore
        }
    
    catch {
        WriteErrorString "Error: Failed to log in to Azure."
        Exit
    }
}

Write-Host -NoNewline "."

if ($settings.Azure.subscriptionID -gt 0) {

    try {
        $out=Set-AzureRmContext -SubscriptionId $settings.Azure.subscriptionID
    }

    catch {
        WriteErrorString "Error: Specified subscriptionID not found."
        Exit
    }
} else {
     WriteErrorString "Error: [Azure] subscriptionID not specified."
     Exit
}

Write-Host ". OK"

$deploymentOption=GetDeploymentSettingOption $settings

if ($uagName.length -gt 32) { 
    WriteErrorString "Error: Virtual machine name must be no more than 32 characters in length"
    Exit
}

if (!$uagName) {
    WriteErrorString "Error: [General] name not specified"
    Exit
}

if (!$rootPwd) {
    $rootPwd = GetRootPwd $uagName
}

if (!$adminPwd) {
    $adminPwd = GetAdminPwd $uagName
}

if (!$ceipEnabled) {
    $ceipEnabled = GetCeipEnabled $uagName
}

$settingsJSON=GetJSONSettings $settings

SetUp

$ovfFile = "${env:APPDATA}\VMware\$uagName.cfg"

[IO.File]::WriteAllLines($ovfFile, [string[]]("deploymentOption="+"$deploymentOption"))

$dns=$settings.General.dns
if ($dns.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("DNS="+"$dns"))
}

$defaultGateway=$settings.General.defaultGateway
if ($defaultGateway.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("defaultGateway="+"$defaultGateway"))
}

$v6DefaultGateway=$settings.General.v6DefaultGateway
if ($v6defaultGateway.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("v6defaultGateway="+"$v6defaultGateway"))
}

$forwardrules=$settings.General.forwardrules
if ($forwardrules.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("forwardrules="+"$forwardrules"))
}

$routes0=$settings.General.routes0
if ($routes0.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("routes0="+"$routes0"))
}

$routes1=$settings.General.routes1
if ($routes1.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("routes1="+"$routes1"))
}

$routes2=$settings.General.routes2
if ($routes2.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("routes2="+"$routes2"))
}

if ($ceipEnabled -eq $false) {
    $ovfOptions += " --prop:ceipEnabled='false'"
    [IO.File]::AppendAllLines($ovfFile, [string[]]("ceipEnabled=false"))
}

if ($settings.General.tlsPortSharingEnabled -eq "true") {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("tlsPortSharingEnabled=true"))
}

if ($settings.General.sshEnabled -eq "true") {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("sshEnabled=true"))
}

if ($settings.General.sshPasswordAccessEnabled -eq "false") {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("sshPasswordAccessEnabled=false"))
}

if ($settings.General.sshKeyAccessEnabled -eq "true") {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("sshKeyAccessEnabled=true"))
}

[IO.File]::AppendAllLines($ovfFile, [string[]]("rootPassword="+"$rootPwd"))

if ($adminPwd.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("adminPassword="+"$adminPwd"))
}

$imageURI = $settings.Azure.imageURI

if ($imageURI.length -eq 0) {
    WriteErrorString "Error: [Azure] imageURI not found"
    [IO.File]::Delete($ovfFile)
    Exit
}

$location = $settings.Azure.location

if ($location.length -gt 0) {
    $res =  Get-AzureRmResourceProvider -Location $settings.Azure.location -ProviderNameSpace Microsoft.Compute
    If([string]::IsNullOrEmpty($res)) {    
        WriteErrorString "Error: [Azure] location ($location) not found"
        $locations = Get-AzureRmResourceProvider -ProviderNameSpace Microsoft.Compute
        $locationNames = $locations[0].Locations
        WriteErrorString "Specify a location from the following list:"
        for ($i=0; $i -lt $locations[0].Locations.Count; $i++) {
            write-host $locations[0].Locations[$i]
        }
        [IO.File]::Delete($ovfFile)
        Exit
    }
} else {
    WriteErrorString "Error: [Azure] location not specified"
    [IO.File]::Delete($ovfFile)
    Exit
}

$resourceGroupName = $settings.Azure.resourceGroupName

if ($resourceGroupName.Length -gt 0) {
    $out = get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    if ($out.ResourceId.Length -eq 0) {
        $out = New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

        $out
        if ($out.ResourceId.Length -eq 0) {
            WriteErrorString "Error: [Azure] resourceGroupName ($resourceGroupName) not found and could not be created"
            [IO.File]::Delete($ovfFile)
            Exit
        }
    }
} else {
     WriteErrorString "Error: [Azure] resourceGroupName not specified."
    [IO.File]::Delete($ovfFile)
     Exit
}

$storageAccountName = $settings.Azure.storageAccountName

if ($storageAccountName.length -gt 0) {
    $storageAcc = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    If($storageAcc.Id.Length -eq 0) { 
        $storageAcc = New-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName -Location $location -SkuName Standard_LRS -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        if ($storageAcc.Id.Length -eq 0) {
            $msg = $error[0]
            WriteErrorString "Error: [Azure] storageAccountName ($storageAccountName) not found and could not be created - $msg"
            [IO.File]::Delete($ovfFile)
            Exit
        }
    }
} else {
    WriteErrorString "Error: [Azure] storageAccountName not specified"
    [IO.File]::Delete($ovfFile)
    Exit
}

$diskStorageContainer = $settings.Azure.diskStorageContainer.ToLower()
if ($diskStorageContainer.length -gt 0) {
    $container = Get-AzureRmStorageContainer -Name $diskStorageContainer -ResourceGroupName $resourceGroupName -AccountName $storageAccountName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    If($container.Name.Length -eq 0) { 
        $container = New-AzureRmStorageContainer -Name $diskStorageContainer -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        if ($container.Name.Length -eq 0) {
            $msg = $error[0]
            WriteErrorString "Error: [Azure] diskStorageContainer ($diskStorageContainer) not found and could not be created - $msg"
            [IO.File]::Delete($ovfFile)
            Exit
        }
    }
} else {
    WriteErrorString "Error: [Azure] diskStorageContainer not specified"
    [IO.File]::Delete($ovfFile)
    Exit
}

DeleteExistingUAGResources $settings $uagName

$vmSize = $settings.Azure.vmSize
if ($vmSize.length -gt 0) {
    write-host "Deploying $uagName as $vmSize"
} else {
    $vmSize = "Standard_A4_v2"
}

#
# Set up the VM object
#

Write-Host -NoNewline "Creating network interfaces .."

$vm = New-AzureRmVMConfig -VMName $uagName -VMSize $vmSize

switch -Wildcard ($deploymentOption) {

    'onenic*' {
        ValidateNetworkSettings $settings "0"
        $eth0 = CreateNIC $settings "0"
        $eth0
        $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $eth0.Id -Primary
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode0=DHCPV4+DHCPV6"))
    }
    'twonic*' {
        ValidateNetworkSettings $settings "0"
        ValidateNetworkSettings $settings "1"
        $eth0 = CreateNIC $settings "0"
        $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $eth0.Id -Primary
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode0=DHCPV4+DHCPV6"))
        $eth1 = CreateNIC $settings "1"
        $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $eth1.Id
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode1=DHCPV4+DHCPV6"))
    }
    'threenic*' {
        ValidateNetworkSettings $settings "0"
        ValidateNetworkSettings $settings "1"
        ValidateNetworkSettings $settings "2" 
        $eth0 = CreateNIC $settings "0"
        $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $eth0.Id -Primary
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode0=DHCPV4+DHCPV6"))
        $eth1 = CreateNIC $settings "1"
        $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $eth1.Id
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode1=DHCPV4+DHCPV6"))
        $eth2 = CreateNIC $settings "2"
        $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $eth2.Id
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode2=DHCPV4+DHCPV6"))
    }
    default {
        WriteErrorString "Error: Invalid deploymentOption ($deploymentOption)."
        [IO.File]::Delete($ovfFile)
        Exit  
    }
}

Write-Host ". OK"

Write-Host -NoNewline "Creating disk image .."

$guid = [guid]::NewGuid()
$diskName = $($uagName+"-"+$guid+"-disk1.vhd")

$osDiskUri = '{0}{1}/{2}' -f $storageAcc.PrimaryEndpoints.Blob.ToString(), $diskStorageContainer, $diskName

#
# Associate the starter disk with the VM object
#

$vm = Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $osDiskUri -CreateOption fromImage -DiskSizeInGB 40 -SourceImageUri $imageURI -Linux

Write-Host ". OK"

Write-Host -NoNewline "Creating virtual appliance .."

#
# Associate the VM settings with VM object. CustomData is base64 encoded OVF properties pushed to the VM.
#

$pwd = GenerateAzureRandomPassword

$securePassword = ConvertTo-SecureString $pwd -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

[IO.File]::AppendAllLines($ovfFile, [string[]]("settingsJSON="+"$settingsJSON"))

$ovfProperties = Get-Content -Raw $ovfFile

$customData = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($ovfProperties))

$vm = Set-AzureRmVMOperatingSystem -VM $vm -Linux -Credential $Credential -ComputerName $uagName -CustomData $customData

$newvm = New-AzureRmVM -ResourceGroupName $resourceGroupName -Location $location -VM $vm -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

if (!$newvm) {
    Write-Host ". FAILED"
    $msg = $error[0]
    WriteErrorString "Error: Failed to create $uagName VM ($msg)."
    [IO.File]::Delete($ovfFile)
    Exit
}

Write-Host ". OK"

write-host "Deployed $uagName successfully to Azure resource group $resourceGroupName"

[IO.File]::Delete($ovfFile)
