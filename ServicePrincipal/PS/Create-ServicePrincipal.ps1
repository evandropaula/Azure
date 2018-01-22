<#
.SYNOPSIS
    Creates a new Service Principal and assigns a role at the desired scope
.DESCRIPTION
    Creates a new Service Principal and assigns a role at the desired scope
.NOTES
    File Name  : Create-ServicePrincipal.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\Create-ServicePrincipal.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -TenantId "398e7a92-6e66-4ae1-8fe1-71564738f2df" -Scope "/subscriptions/f4f718ef-c9ed-429c-9bb5-614c999b91d3" -ServicePrincipalName "spn" -Password "p@zzw0rd" -Role "Contributor"
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
    $Scope,

    [Parameter(Mandatory=$true)]
    [String]
    $ServicePrincipalName,

    # This is the password used for login with the Service Principal
    [Parameter(Mandatory=$true)]
    [String]
    $Password,

    [Parameter(Mandatory=$true)]
    [String]
    $Role
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
Set-AzureRmContext -SubscriptionId $SubscriptionId -ErrorAction Stop
WriteSuccess


# Create Service Principal ---------------------------------------------->
WriteTitle("SERVICE PRINCIPAL")

# Create AD application
WriteText("Provisioning AD Application...")

# A secure string is required for the password on New-AzureRmADApplication, find more details at https://github.com/Azure/azure-powershell/issues/4971
$securePassword = ConvertTo-SecureString $Password -asplaintext -force
$Application = New-AzureRmADApplication -DisplayName $ServicePrincipalName -HomePage ("http://" + $ServicePrincipalName) -IdentifierUris ("http://" + $ServicePrincipalName) -Password $securePassword -ErrorAction Stop
WriteSuccess

# Create Service Principal for the AD Application ----------------------->
WriteText("Provisioning Service Principal for AD Application...")
$ServicePrincipal = New-AzureRMADServicePrincipal -ApplicationId $Application.ApplicationId -ErrorAction Stop
Get-AzureRmADServicePrincipal -ObjectId $ServicePrincipal.Id
WriteSuccess


# Create Service Principal ---------------------------------------------->
WriteTitle("ROLE ASSIGNMENT")

$maxRetry = 20
$waitTimeIntervalMs = 5000
$isRoleAssignmentCompleted = $false

for ($i=0; $i -lt $maxRetry; $i++)
{
    WriteText("Assigning role '$($Role)' to Service Principal Applicaiton Id '$($ServicePrincipal.ApplicationId)' at Scope '$($Scope)'...")
    New-AzureRmRoleAssignment -Scope $Scope -ObjectId $ServicePrincipal.Id -RoleDefinitionName $Role -ErrorAction SilentlyContinue -ErrorVariable err
    WriteText

    # Rollback if an error occurs
    if ($err.Count -gt 0)
    {
        WriteText("Failed! Waiting '$($waitTimeIntervalMs)' ms for changes to be available in AAD and retrying (retry = $($i))...")
        Start-Sleep -Milliseconds $waitTimeIntervalMs
        WriteText
    }
    else
    {
        $isRoleAssignmentCompleted = $true
        break;
    }
}

if ($isRoleAssignmentCompleted -eq $false)
{
    WriteError("[Error] $($err)")
    WriteText
    WriteError("Role assignment failed...")
    return -1
}

WriteSuccess


# Login to Azure -------------------------------------------------------->
WriteTitle("AUTHENTICATION")
WriteText("Logging in to Azure to test the Service Principal account just created...")

$creds = New-Object System.Management.Automation.PSCredential ($Application.ApplicationId, $securePassword)
Add-AzureRmAccount -ServicePrincipal -Credential $creds -TenantId $TenantId -ErrorAction Stop
WriteSuccess


return 0