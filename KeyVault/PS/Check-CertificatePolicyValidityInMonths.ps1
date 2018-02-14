<#
.SYNOPSIS
    Validates and/or fixes all certificates policy in Azure Key Vault to ensure ValidityInMonths is not greater than 27 months
.DESCRIPTION
    Validate and/or fixes all certificates policy in Azure Key Vault to ensure ValidityInMonths is not greater than 27 months
    
    CAUTION: Recommendation is to set ValidityInMonths no longer than 2 years
.NOTES
    File Name  : Set-ServicePrincipalPermissions.ps1
    Author     : Evandro de Paula
.EXAMPLE
    Only validates on all certificates in a Azure Key Vault 
        .\Check-CertificatePolicyValidityInMonths.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -KeyVaultName "kv" -KeyVaultResourceGroupName "rg"

    Validates and sets outliers certificates policies ValidityInMonths to 24 months
        .\Check-CertificatePolicyValidityInMonths.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -KeyVaultName "kv" -KeyVaultResourceGroupName "rg" -Fix $True

    Overrides the ValidityInMonths to a number other than 24 months
        .\Check-CertificatePolicyValidityInMonths.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -KeyVaultName "kv" -KeyVaultResourceGroupName "rg" -Fix $True -NewValidityInMonths 27
#>

Param (
    [Parameter(Mandatory=$true)]
    [String]
    $SubscriptionId,
 
    [Parameter(Mandatory=$true)]
    [String]
    $KeyVaultName,
 
    [Parameter(Mandatory=$true)]
    [String]
    $KeyVaultResourceGroupName,

    [Parameter(Mandatory=$false)]
    [Boolean]
    $Fix = $False,

    [Parameter(Mandatory=$false)]
    [ValidateRange(0,27)]
    [Int]
    $NewValidityInMonths = 24
)
 
# Modules --------------------------------------------------------------->
Import-Module AzureRM.Resources
 
 
# Helper Functions ------------------------------------------------------>
. ..\..\Common\PS\Util.ps1
 
 
# Login to Azure -------------------------------------------------------->
WriteTitle("AUTHENTICATION")
WriteText("Logging in to Azure...")
Login-AzureRmAccount -ErrorAction Stop
WriteSuccess


# Set Context to Subscription Id ---------------------------------------->
WriteTitle("SUBSCRIPTION CONTEXT")
WriteText("Setting subscription context...")
Set-AzureRmContext  -SubscriptionId $SubscriptionId -ErrorAction Stop
WriteSuccess


# Set Key Vault Permissions to Service Principal ------------------------>
WriteTitle("KEY VAULT")
WriteText("Reading all certificates on Key Vault '$($KeyVaultName)'...")

# Read all certificates from Key Vault
$certificates = Get-AzureKeyVaultCertificate –VaultName $KeyVaultName

if ($certificates -eq $null -Or $certificates.length -eq 0)
{
    # Exit if there are no certificates to do any work
    WriteError("No certificates were found on Key Vault '$keyVaultName'...")
    return -1
}

for ($i=0; $i -lt $certificates.length; $i++)
{
    $certificatePolicy = Get-AzureKeyVaultCertificatePolicy -VaultName $KeyVaultName -Name $certificates[$i].Name
    $certificatePolicy

    if ($certificatePolicy.ValidityInMonths -gt 27)
    {
        WriteText("Certificate '$($certificates[$i].Name)' validity in months is GREATER THAN 27 months...")

        if ($Fix -eq $True)
        {
            WriteText("Updating policy validity in months to $($NewValidityInMonths)")

            # Changing the validity in months to 24 months
            $certificatePolicy.ValidityInMonths = $NewValidityInMonths

            # Updating the policy
            Set-AzureKeyVaultCertificatePolicy -VaultName $KeyVaultName -CertificateName $certificates[$i].Name -CertificatePolicy $certificatePolicy
        }
    }
    else
    {
        WriteText("Certificate '$($certificates[$i].Name)' validity in months if OK. No change is required.")
    }

    WriteSuccess
}

WriteText

WriteSuccess

return 0