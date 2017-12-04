<#
.SYNOPSIS
    Creates a new Service Principal and assigns a role at the desired scope
.DESCRIPTION
    Creates a new Service Principal and assigns a role at the desired scope
.NOTES
    File Name  : Create-ServicePrincipal.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\Create-ServicePrincipal.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -Scope "/subscriptions/f4f718ef-c9ed-429c-9bb5-614c999b91d3" -ServicePrincipalName "spn" -Password "p@zzw0rd" -Role "Contributor"
#>


Param (
    [Parameter(Mandatory=$true)]
    [String]
    $SubscriptionId,

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
$Application = New-AzureRmADApplication -DisplayName $ServicePrincipalName -HomePage ("http://" + $ServicePrincipalName) -IdentifierUris ("http://" + $ServicePrincipalName) -Password $Password -ErrorAction Stop
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


return 0