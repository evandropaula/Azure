<#
.SYNOPSIS
    Enable Azure Key Vault logging to storage account, which enables security teams to audit any changes in objects in the vault.
.DESCRIPTION
     Enable Azure Key Vault logging to storage account, which enables security teams to audit any changes in objects in the vault.
.NOTES
    File Name  : EnableDiagnostics.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\EnableDiagnostics.ps1 -SubscriptionId "81d52103-cd8d-419f-8e4f-1cb583abaecb" -TenantId "d6ce820e-babb-4938-a270-f8ba49771765" -ServicePrincipalApplicationId "72efd09b-39c2-4ea7-96f1-fca6d5a4ee3a" -Password "password" -KeyVaultName "kv" -StorageAccountName "kvdiag" -ResourceGroupName "kvrg"
#>

Param (
    [Parameter(Mandatory=$true)]
    [String]
    $SubscriptionId,

    [Parameter(Mandatory=$true)]
    [String]
    $TenantId,

    [Parameter(Mandatory=$true)]
    [String]
    $ServicePrincipalApplicationId,

    # This is the password used for login with the Service Principal
    [Parameter(Mandatory=$true)]
    [String]
    $Password,
 
    [Parameter(Mandatory=$false)]
    [String]
    $KeyVaultName,
 
    [Parameter(Mandatory=$false)]
    [String]
    $StorageAccountName,

    [Parameter(Mandatory=$false)]
    [String]
    $ResourceGroupName
)


# Modules --------------------------------------------------------------->
Import-Module AzureRM.Resources


# Helper Functions ------------------------------------------------------>
Try
{
    . ..\..\Common\PS\Util.ps1
}
Catch [System.Management.Automation.CommandNotFoundException]
{
    # Ignoring errors in case the script has been ALREADY LOADED by the caller script in a different directory (e.g. .\platform-azure-foundation\CardFulfillment\Dev\EastUS\CreateSecrets.ps1)
}


# Login to Azure -------------------------------------------------------->
WriteTitle("AUTHENTICATION")
WriteText("Logging in to Azure...")

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential ($ServicePrincipalApplicationId, $securePassword)
Add-AzureRmAccount -ServicePrincipal -Credential $creds -TenantId $TenantId -ErrorAction Stop
WriteSuccess


# Set Context to Subscription Id ---------------------------------------->
WriteTitle("SUBSCRIPTION SELECTION")
WriteText("Setting subscription context...")
Select-AzureRmSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop
WriteSuccess


# Enable Diagnostics Log ------------------------------------------------>
WriteTitle("DIAGNOSTICS SETTINGS")
WriteText("Enabling diagnostics for the Azure Key Vault...")

$keyVault = Get-AzureRmKeyVault -ResourceGroupName $ResourceGroupName -VaultName $KeyVaultName -ErrorAction Stop
$storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop

Set-AzureRmDiagnosticSetting -ResourceId $keyVault.ResourceId -StorageAccountId $storageAccount.Id -Enabled $true -RetentionEnabled $true -RetentionInDays 90 -Categories AuditEvent
WriteSuccess


return 0