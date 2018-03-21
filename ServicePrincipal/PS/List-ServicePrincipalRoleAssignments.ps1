<#
.SYNOPSIS
    List all Service Principal role assigments (e.g. Contributor) including properties such as Scope, RoleName, etc.
.DESCRIPTION
    List all Service Principal role assigments (e.g. Contributor) including properties such as Scope, RoleName, etc.
.NOTES
    File Name  : List-ServicePrincipalRoleAssignments.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\List-ServicePrincipalRoleAssignments.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -TenantId "398e7a92-6e66-4ae1-8fe1-71564738f2df" -ServicePrincipalApplicationId "64da15a3-5e47-48ce-b73f-8ed7b06d6bca"
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
    $ServicePrincipalApplicationId
)


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


# Check if Service Principal exists ------------------------------------->
WriteTitle("SERVICE PRINCIPAL")
WriteText("Loading service principal...")

$servicePrincipal = Get-AzureRmADServicePrincipal -ServicePrincipalName $ServicePrincipalApplicationId -ErrorAction Stop

if ($servicePrincipal -eq $null)
{
    WriteError("Service Principal with Application Id '$($ServicePrincipalApplicationId)' was not found...")
    return -1
}

WriteSuccess


# List role assigments for Service Principal ---------------------------->
WriteTitle("ROLE ASSIGNMENT")
WriteText("Listing role assignments for Service Principal Application Id '$($ServicePrincipalApplicationId)'...")

$roleAssignments = Get-AzureRmRoleAssignment -ServicePrincipalName $ServicePrincipalApplicationId -ErrorAction SilentlyContinue

# No role assignments found
if ($roleAssignments -eq $null -or $roleAssignments.Count -eq 0)
{
    WriteError("Service Principal wit Application Id '$($ServicePrincipalApplicationId)' does not have any role assignment...")
    return -2
}

# List role assignments
for ($i = 0; $i -lt $roleAssignments.Count; $i++)
{
    $roleAssignments[$i]
}

WriteSuccess


return 0