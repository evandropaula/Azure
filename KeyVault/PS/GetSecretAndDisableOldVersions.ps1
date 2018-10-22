<#
.SYNOPSIS
    Read a secret value from Azure Key Vault.
    Optionally, it can disable past versions of the secret leaving the latest 2 versions enabled to support secret rollover without service disruption.
.DESCRIPTION
    Read a secret value from Azure Key Vault.
    Optionally, it can disable past versions of the secret leaving the latest 2 versions enabled to support secret rollover without service disruption.
    Remarks:
    a) Only the most recent 2 versions of the secret will be enabled to support secret rollover without any service disruption;
    b) Secret version will be disabled until the script finds a secret version that is already disabled;
    c) By default, disabling the old version flag is turned off. However, this behavior is likely desired for security purposes. Check with your security team/division what are the controls and policies for this; 
.NOTES
    File Name  : GetSecretAndDisableOldVersions.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\GetSecretAndDisableOldVersions.ps1 -SubscriptionId "fc513365-0821-451c-a5b3-acf82568d8ce" -TenantId "ee69be27-d938-4eb5-8711-c5e69ca43718" -ServicePrincipalApplicationId "<Service Principal ApplicationId (Guid)>" -Password "<Service Principal Password or Key (String)>" -keyVaultName "s00197npkvt00001" -SecretNames "s00197tbl0crdfuldev0-ReadOnlyConnectionString"
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
    [String[]]
    $SecretNames,

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


# Read Secrets ---------------------------------------------------------->
WriteTitle("READ SECRETS")

for ($j=0; $j -lt $SecretNames.length; $j++)
{
    $SecretName = $SecretNames[$j]

    WriteText("Reading secret '$($SecretName)' latest version...")
    Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -ErrorAction Stop
    WriteSuccess

    # Disable Old/Unused Versions (if any)
    if ($DisableOldVersions -eq $true)
    {
        WriteTitle("DISABLE UNUSED SECRETS")
        WriteText("Disabling secret '$($SecretName)' old versions, only first 2 will be left enabled...")
        WriteText

        $secretVersions = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -IncludeVersions -ErrorAction Stop

        for ($i=0; $i -lt $secretVersions.length; $i++)
        {
            if ($i -gt 1) # Skip the latest 2 versions to ensure they are enabled
            {
                if ($secretVersions[$i].Enabled -eq $true)
                {
                    # Disable secret version if it is enabled
                    WriteText("Disabling secret '$($secretVersions[$i].Name)' version '$($secretVersions[$i].Version)'...")
                    Set-AzureKeyVaultSecretAttribute -VaultName $KeyVaultName -Name $secretVersions[$i].Name -Version $secretVersions[$i].Version -Enable $false -ErrorAction Stop
                    WriteSuccess
                }
                else
                {
                    WriteText("Secret '$($secretVersions[$i].Name)' version '$($secretVersions[$i].Version)' is already disabled, moving on to the next secret (if any)...")
                    WriteSuccess
                    break
                }
            }
        }
    }
}


return 0