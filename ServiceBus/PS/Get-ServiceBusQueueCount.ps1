<#
.SYNOPSIS
    Get service bus queue details along with message count
.DESCRIPTION
    Get service bus queue details along with message count
.NOTES
    File Name  : Get-ServiceBusQueueCount.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\Get-ServiceBusQueueCount.ps1 -SubscriptionId "1c979e27-947d-4d9f-b9ef-9aa0df0fcb68" -TenantId "961176d8-efc4-48e3-b48d-e5afda58504b" -ServicePrincipalApplicationId "<Service Principal ApplicationId (Guid)>" -Password "<Service Principal Password or Key (String)>" -ServiceBusResourceGroupName "rg" -ServiceBusNamespaceName "sbns" -ServiceBusQueueName "sbqueue"
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
    $ServiceBusResourceGroupName,

    [Parameter(Mandatory=$true)]
    [String]
    $ServiceBusNamespaceName,

    [Parameter(Mandatory=$true)]
    [String]
    $ServiceBusQueueName
)


# Modules --------------------------------------------------------------->
Import-Module AzureRM.Resources


# Helper Functions ------------------------------------------------------>
. ..\..\Common\PS\Util.ps1


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


# Service Bus ----------------------------------------------------------->
WriteTitle("SERVICE BUS")
WriteText("Loading service bus queue...")
$serviceBusQueue = Get-AzureRmServiceBusQueue -ResourceGroup $ServiceBusResourceGroupName -NamespaceName $ServiceBusNamespaceName -QueueName $ServiceBusQueueName
$serviceBusQueue
WriteSuccess

WriteText("Loading service bus queue count details...")
$serviceBusQueue.CountDetails
WriteSuccess

return 0