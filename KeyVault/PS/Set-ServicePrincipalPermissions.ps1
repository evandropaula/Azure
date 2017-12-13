<#
.SYNOPSIS
    Assign Azure Key Vault permissions to a Service Principal
.DESCRIPTION
    Assign Azure Key Vault permissions to a Service Principal, based on its type:
    a) ReadWrite: this Service Principal will have all permissions to certificates, keys and secrets and it is intended to be used during deployment or other management operations;
    a) ReadOnly: this Service Principal will have read-only permissions to certificates, keys and secrets and it is intended to be used in runtime by applications;

    CAUTION: Make sure to refresh the entire page after running this script because the Azure portal UI sometimes does not refresh correctly.
.NOTES
    File Name  : Set-ServicePrincipalPermissions.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\Set-ServicePrincipalPermissions.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -ServicePrincipalObjectId "b05974bb-b85c-424e-b7f1-a3a4b4e19729" -ServicePrincipalType ReadWrite -keyVaultName "kvt" -keyVaultResourceGroupName "rg"
    .\Set-ServicePrincipalPermissions.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -ServicePrincipalObjectId "b05974bb-b85c-424e-b7f1-a3a4b4e19729" -ServicePrincipalType ReadOnly -keyVaultName "kvt" -keyVaultResourceGroupName "rg"
#>

Param (
    [Parameter(Mandatory=$true)]
    [String]
    $SubscriptionId,

    [Parameter(Mandatory=$true)]
    [String]
    $ServicePrincipalObjectId,
 
    [ValidateSet("ReadWrite","ReadOnly")]
    [Parameter(Mandatory=$true)]
    [String]
    $ServicePrincipalType,
 
    [Parameter(Mandatory=$true)]
    [String]
    $keyVaultName,
 
    [Parameter(Mandatory=$true)]
    [String]
    $keyVaultResourceGroupName
)
 
# Modules --------------------------------------------------------------->
Import-Module AzureRM.Resources
 
 
# Helper Functions ------------------------------------------------------>
. ..\..\Common\PS\Util.ps1
 
 
# Login to Azure -------------------------------------------------------->
WriteTitle("AUTHENTICATION")
WriteText("Logging in to Azure...")
#Login-AzureRmAccount -ErrorAction Stop
WriteSuccess


# Set Context to Subscription Id ---------------------------------------->
WriteTitle("SUBSCRIPTION CONTEXT")
WriteText("Setting subscription context...")
Set-AzureRmContext  -SubscriptionId $SubscriptionId -ErrorAction Stop
WriteSuccess


# Set Key Vault Permissions to Service Principal ------------------------>
WriteTitle("KEY VAULT PERMISSIONS")
WriteText("Assigning Key Vault permissions to Service Principal (ObjectId=$($ServicePrincipalObjectId))...")

if ($ServicePrincipalType -eq "ReadOnly")
{
    WriteText("Setting READ-ONLY permissions...")
    Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -ResourceGroupName $keyVaultResourceGroupName -ObjectId $ServicePrincipalObjectId -PermissionsToCertificates list,get,listissuers,getissuers -PermissionsToKeys list,get,decrypt,unwrapKey -PermissionsToSecrets list,get
}
else
{
    # DO NOT uset the "all" permission beacuse it is deprecated
    WriteText("Setting ALL permissions...")
    Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -ResourceGroupName $keyVaultResourceGroupName -ObjectId $ServicePrincipalObjectId -PermissionsToCertificates get,list,delete,create,import,update,managecontacts,getissuers,listissuers,setissuers,deleteissuers,manageissuers -PermissionsToKeys decrypt,encrypt,unwrapKey,wrapKey,verify,sign,get,list,update,create,import,delete,backup,restore,recover,purge -PermissionsToSecrets get,list,set,delete,backup,restore,recover,purge
}

WriteSuccess

return 0