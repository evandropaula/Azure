<#
.SYNOPSIS
    Assigns a role (e.g. Contributor) to an existent Service Principal account in a scope (e.g. subscription, resource group, etc.) 
.DESCRIPTION
    Assigns a role (e.g. Contributor) to an existent Service Principal account in a scope (e.g. subscription, resource group, etc.)
.NOTES
    File Name  : Assign-ServicePrincipalRole.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\Assign-ServicePrincipalRole.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -TenantId "398e7a92-6e66-4ae1-8fe1-71564738f2df" -ServicePrincipalApplicationId "64da15a3-5e47-48ce-b73f-8ed7b06d6bca" -Scope "/subscriptions/f4f718ef-c9ed-429c-9bb5-614c999b91d3" -Role "Contributor"
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

    [Parameter(Mandatory=$true)]
    [String]
    $Scope,

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


# Load Service Principal ------------------------------------------------>
WriteTitle("SERVICE PRINCIPAL")
WriteText("Loading service principal...")

$servicePrincipal = Get-AzureRmADServicePrincipal -ServicePrincipalName $ServicePrincipalApplicationId -ErrorAction Stop

if ($servicePrincipal -eq $null)
{
    WriteError("Service Principal with Application Id '$($ServicePrincipalApplicationId)' was not found...")
    return -1
}

# Role Assigment to Service Principal ----------------------------------->
WriteTitle("ROLE ASSIGNMENT")
WriteText("Assigning role '$($Role)' to Service Principal Object Id '$($servicePrincipal.Id)' at Scope '$($Scope)'...")

New-AzureRmRoleAssignment -Scope $Scope -ObjectId $servicePrincipal.Id -RoleDefinitionName $Role -ErrorAction Stop

WriteText

WriteSuccess


return 0