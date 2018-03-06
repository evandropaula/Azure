<#
.SYNOPSIS
    Searches Key Vault secrets by name through a regular expression.
.DESCRIPTION
    Searches Key Vault secrets by name through a regular expression.
    In addition, there is an option to include the secret values or not. Search will perform better if you do not include the secret values. 
    Even though certificates are stored in Key Vault as secrets, those will be filtered out of the results.

    CAUTION: running this against production environments MAY impact availability depending on the total number of secrets and script execution frequency
.NOTES
    File Name   : Search-KeyVaultSecretsByName.ps1
    Author      : Evandro de Paula
    Tested on   : Windows 10, Ubuntu 16.04
.EXAMPLE
    .\Search-KeyVaultSecretsByName.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -KeyVaultName "kv"
    .\Search-KeyVaultSecretsByName.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -KeyVaultName "kv" -IncludeSecretValue $true
    .\Search-KeyVaultSecretsByName.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -KeyVaultName "kv" -RegularExpression "abc"
    .\Search-KeyVaultSecretsByName.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -KeyVaultName "kv" -RegularExpression "[a-z]abc"
    .\Search-KeyVaultSecretsByName.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -KeyVaultName "kv" -RegularExpression "[a-z]abc" -IncludeSecretValue $true
#>

Param (
    [Parameter(Mandatory=$true)]
    [String]
    $SubscriptionId,
 
    [Parameter(Mandatory=$true)]
    [String]
    $KeyVaultName,

    [Parameter(Mandatory=$false)]
    [String]
    $RegularExpression,

    [Parameter(Mandatory=$false)]
    [bool]
    $IncludeSecretValue
)
 
 
# Helper Functions ------------------------------------------------------>
. ..\..\Common\PS\Util.ps1
 
 
# Login to Azure -------------------------------------------------------->
WriteTitle("AUTHENTICATION")
WriteText("Logging in to Azure...")

$context = Get-AzureRmContext -ErrorAction Continue

if ([string]::IsNullOrWhiteSpace($context.Subscription.Name))
{
    Login-AzureRmAccount -ErrorAction Stop
}

WriteSuccess


# Set Context to Subscription Id ---------------------------------------->
WriteTitle("SUBSCRIPTION CONTEXT")
WriteText("Setting subscription context...")
Set-AzureRmContext  -SubscriptionId $SubscriptionId -ErrorAction Stop
WriteSuccess


# Set Key Vault Permissions to Service Principal ------------------------>
WriteTitle("KEY VAULT SECRETS")
WriteText("Reading all secrets from Key Vault '($($KeyVaultName))'...")

# List all secrets
# CAUTION: running this against production environments MAY impact availability depending on the total number of secrets and script execution frequency
$secrets = Get-AzureKeyVaultSecret -VaultName $KeyVaultName

WriteSuccess

for ($i = 0; $i -lt $secrets.Count; $i++)
{
    if (([string]::IsNullOrWhiteSpace($RegularExpression) -eq $true) -or ([string]::IsNullOrWhiteSpace($RegularExpression) -eq $false -and $secrets[$i].Name -match $RegularExpression))
    {
        # Skip certificates by filtering out secrets with content-type "application/x-pkcs12" or "application/x-pem-file"
        if ([string]::IsNullOrWhiteSpace($secrets[$i].ContentType) -eq $false -and ($secrets[$i].ContentType.Equals("application/x-pkcs12", [System.StringComparison]::InvariantCultureIgnoreCase) -or $secrets[$i].ContentType.Equals("application/x-pem-file", [System.StringComparison]::InvariantCultureIgnoreCase)))
        {
            continue;
        }

        # Print major properties
        WriteText("Name = $($secrets[$i].Name)")
        WriteText("Id = $($secrets[$i].Id)")

        if ($IncludeSecretValue -eq $true)
        {
            # Get secret latest version (if requested)
            $secret = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $secrets[$i].Name

            WriteText("SecretValueText = $($secret.SecretValueText)")
            WriteText("LatestVersion = $($secret.Version)")
        }

        WriteSuccess
    }
}

return 0