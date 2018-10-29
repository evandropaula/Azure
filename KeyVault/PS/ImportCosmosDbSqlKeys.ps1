<#
.SYNOPSIS
    Retrieve CosmosDB/SQL access keys and import them to Azure Key Vault
.DESCRIPTION
    Retrieve CosmosDB/SQL access keys and import them to Azure Key Vault
.NOTES
    File Name  : ImportCosmosDbSqlKeys.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\ImportCosmosDbSqlKeys.ps1 -SubscriptionId "1c979e27-947d-4d9f-b9ef-9aa0df0fcb68" -TenantId "961176d8-efc4-48e3-b48d-e5afda58504b" -ServicePrincipalApplicationId "<Service Principal ApplicationId (Guid)>" -Password "<Service Principal Password or Key (String)>" -keyVaultName "kv" -CosmosDbSqlResourceGroupName "rg" -ResourceType "Microsoft.DocumentDb/databaseAccounts" -CosmosDbSqlAccountName "cosmosdbsql"
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

    [Parameter(Mandatory=$true)]
    [String]
    $KeyVaultName,

    [Parameter(Mandatory=$true)]
    [String]
    $CosmosDbSqlResourceGroupName,

    [Parameter(Mandatory=$true)]
    [String]
    $ResourceType,

    [Parameter(Mandatory=$true)]
    [String]
    $CosmosDbSqlAccountName,
    
    [Parameter(Mandatory=$false)]
    [bool]
    $DisableOldVersions = $false
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
Select-AzureRmSubscription -SubscriptionId $SubscriptionId
WriteSuccess


# Secrets --------------------------------------------------------------->
WriteTitle("SECRETS")


# ATTENTION:
# There is an open issue at https://github.com/Azure/azure-powershell/issues/3650 about listConnectionStrings action returning an empty result
# This prevents automation to have a secret for the entire connection string
# For now, we will upload only the access keys
WriteText("Reading access keys from CosmosDB/SQL account '${$CosmosDbSqlAccountName}'...") 
$keys = Invoke-AzureRmResourceAction -Action listKeys -ResourceType $ResourceType -ApiVersion "2016-03-31" -ResourceGroupName $CosmosDbSqlResourceGroupName -Name $CosmosDbSqlAccountName -Force -ErrorAction Stop
$keys
WriteSuccess

# Prepare arrays with secret names and values
$secretNames = @("$($CosmosDbSqlAccountName)-primaryMasterKey", "$($CosmosDbSqlAccountName)-secondaryMasterKey", "$($CosmosDbSqlAccountName)-primaryReadonlyMasterKey", "$($CosmosDbSqlAccountName)-secondaryReadonlyMasterKey")
$secretValues = @($keys.primaryMasterKey, $keys.secondaryMasterKey, $keys.secondaryReadonlyMasterKey, $keys.primaryReadonlyMasterKey)

# Upload
for ($i=0; $i -lt $secretNames.length; $i++)
{
    # Create secret
    WriteText("Creating secret '$($secretNames[$i])'...")
    $SecretValueSecureString = ConvertTo-SecureString -String $secretValues[$i] -AsPlainText -Force
    Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $secretNames[$i] -SecretValue $SecretValueSecureString -ErrorAction Stop
    WriteSuccess

    # Disable Old/Unused Versions (if any) and if flag is set to true
    if ($DisableOldVersions -eq $true)
    {
        # Read all secret versions
        $secretVersions = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $secretNames[$i] -IncludeVersions -ErrorAction Stop

        if ($secretVersions.length -lt 3) # Only two versions found, no need to disable
        {
            WriteText("No more than two versions of secret '$($secretNames[$i])' found, nothing to disable...")
            WriteSuccess
        }
        else
        {
            WriteText("Disabling secret '$($secretNames[$i])' old versions, only first 2 will be left enabled...")
            for ($j=0; $j -lt $secretVersions.length; $j++)
            {
                if ($j -gt 1) # Skip the latest 2 versions to ensure they are enabled
                {
                    if ($secretVersions[$j].Enabled -eq $true)
                    {
                        # Disable secret version if it is enabled
                        WriteText("Disabling secret '$($secretVersions[$j].Name)' version '$($secretVersions[$j].Version)'...")
                        Set-AzureKeyVaultSecretAttribute -VaultName $KeyVaultName -Name $secretVersions[$j].Name -Version $secretVersions[$j].Version -Enable $false -ErrorAction Stop
                        WriteSuccess
                    }
                    else
                    {
                        WriteText("Secret '$($secretVersions[$j].Name)' version '$($secretVersions[$j].Version)' is already disabled, moving on to the next secret (if any)...")
                        WriteSuccess
                        break
                    }                    
                }
            }
        }
    }
}

return 0