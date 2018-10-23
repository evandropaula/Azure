<#
.SYNOPSIS
    Imports generic secret value into Azure Key Vault
.DESCRIPTION
    Imports generic secret value into Azure Key Vault
    Remarks:
    a) Old secret versions will be disabled until the script finds a version that is already disabled;
    b) By default, disabling the old version flag is turned off. However, this behavior is likely desired for security purposes. Check with your security team/division what are the controls and policies for this;
.NOTES
    File Name  : ImportGenericSecret.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\ImportGenericSecret.ps1 -SubscriptionId "1c979e27-947d-4d9f-b9ef-9aa0df0fcb68" -TenantId "961176d8-efc4-48e3-b48d-e5afda58504b" -ServicePrincipalApplicationId "<Service Principal ApplicationId (Guid)>" -Password "<Service Principal Password or Key (String)>" -keyVaultName "kvname" -SecretName "SecretGreetingMessage" -SecretValue "Hello world!"
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
    $SecretName,

    [Parameter(Mandatory=$true)]
    [String]
    $SecretValue,

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
WriteText("Creating secret '$($SecretName)'...")
$SecretValueSecureString = ConvertTo-SecureString -String $SecretValue -AsPlainText -Force
Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -SecretValue $SecretValueSecureString -ErrorAction Stop
WriteSuccess


# Disable Unused Versions (if any and flag is true) --------------------->
if ($DisableOldVersions -eq $true)
{
    WriteTitle("DISABLE UNUSED SECRETS")

    $secretVersions = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -IncludeVersions -ErrorAction Stop

    if ($secretVersions.length -lt 3)
    {
        # Not enough old versions found to be disabled since the latest 2 have to be enabled to support
        # secret rollover without any disruption
        WriteText("No old secret versions found to be disabled, exiting...")
    }
    else 
    {
        WriteText("Disabling secret '$($SecretName)' old versions, only latest 2 versions will be left enabled...")

        for ($i=0; $i -lt $secretVersions.length; $i++)
        {
            if ($i -gt 1)
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
                    WriteText("Secret '$($secretVersions[$i].Name)' version '$($secretVersions[$i].Version)' is already disabled, exiting...")
                    WriteSuccess

                    # Break execution when the first already disabled secret version is found
                    break
                }
            }
        }
    }
}


return 0