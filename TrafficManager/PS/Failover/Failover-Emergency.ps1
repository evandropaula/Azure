<#
.SYNOPSIS
    Failover Traffic Manager and CosmosDB/DocumentDB to handle a region failure
.DESCRIPTION
    Failover Traffic Manager and CosmosDB/DocumentDB to handle a region failure
    Input determines the DESIRED state for Traffic Manager and CosmosDB/DocumentDB
    There is no rollback or failbabck, which should be handled by running the script with inverted settings

.NOTES
    File Name  : Failover.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\Failover.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -TenantId "e6e208d1-2717-49da-8ad9-982b68b1308f" -TrafficManagerResourceGroupName "rg" -TrafficManagerProfileName "tmp" -TrafficManagerPrimaryEndpointName "endpointname" -DocumentDBResourceGroupName "rg" -DocumentDBAccountName "docdb" -DocumentDBPrimaryLocation "West US" -DocumentDBSecondaryLocation "East US"
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
    $TrafficManagerResourceGroupName,

    [Parameter(Mandatory=$true)]
    [String]
    $TrafficManagerProfileName,

    [Parameter(Mandatory=$true)]
    [String]
    $TrafficManagerPrimaryEndpointName,

    [Parameter(Mandatory=$true)]
    [String]
    $DocumentDBResourceGroupName,

    [Parameter(Mandatory=$true)]
    [String]
    $DocumentDBAccountName,

    [Parameter(Mandatory=$true)]
    [String]
    $DocumentDBPrimaryLocation,

    [Parameter(Mandatory=$true)]
    [String]
    $DocumentDBSecondaryLocation
)


# Modules --------------------------------------------------------------->
Import-Module AzureRM.Resources


# Helper Functions ------------------------------------------------------>
. .\Util.ps1


# Global Variable ------------------------------------------------------->
$disabledStatus = "Disabled"
$enabledStatus = "Enabled"


# Login to Azure -------------------------------------------------------->
WriteTitle("AUTHENTICATION")
WriteText("Logging in to Azure...")
Login-AzureRmAccount -ErrorAction Stop
WriteSuccess


# Set Context to Subscription Id ---------------------------------------->
WriteTitle("SUBSCRIPTION SELECTION")
WriteText("Setting subscription context...")
Select-AzureRmSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop
WriteSuccess


# Get Traffic Manager Profile ------------------------------------------->
WriteTitle("TRAFFIC MANAGER")
WriteText("Reading Traffic Manager Profile...")
$profile = Get-AzureRmTrafficManagerProfile -Name $TrafficManagerProfileName -ResourceGroupName $TrafficManagerResourceGroupName -ErrorAction Stop
$profile
WriteSuccess


# Failover - Traffic Manager -------------------------------------------->
WriteTitle("FAILOVER - TRAFFIC MANAGER")

$primaryEndpoint = $null

# Enable primary endpoint and set its weight to 100
for ($i=0; $i -lt $profile.Endpoints.Count; $i++)
{
    $endpoint = $profile.Endpoints[$i]

    if ($endpoint.Name.Equals($TrafficManagerPrimaryEndpointName, [System.StringComparison]::InvariantCultureIgnoreCase))
    {
        $primaryEndpoint = $endpoint

        $primaryEndpoint.EndpointStatus = $enabledStatus
        $primaryEndpoint.Weight = 100

        WriteText("Updating PRIMARY endpoint '$($primaryEndpoint.Name)' => Status = $($primaryEndpoint.EndpointStatus); Weight = $($primaryEndpoint.Weight);...")
        Set-AzureRmTrafficManagerEndpoint -TrafficManagerEndpoint $primaryEndpoint -ErrorAction Stop
        WriteSuccess

        break;
    }
}

# Ensures the primary endpoint was found in order to proceed
if ($primaryEndpoint -eq $null)
{
    WriteError("Primary endpoint $($TrafficManagerPrimaryEndpointName) was not found. Exiting...")
    return -1
}

# Wait for the primary endpoint to become online
# 5 minutes based on retry and wait time
$maxRetry = 60
$waitTimeIntervalMs = 5000
$isPrimaryEndpointOnline = $false
$onlineMonitorStatus = "Online"
        
for ($i=0; $i -lt $maxRetry; $i++)
{
    $currentPrimaryEndpoint = Get-AzureRmTrafficManagerEndpoint -Name $primaryEndpoint.Name -Type $primaryEndpoint.Type -ProfileName $TrafficManagerProfileName -ResourceGroupName $TrafficManagerResourceGroupName -ErrorAction Continue

    if ($currentPrimaryEndpoint.EndpointMonitorStatus.Equals($onlineMonitorStatus, [System.StringComparison]::InvariantCultureIgnoreCase))
    {
        $isPrimaryEndpointOnline = $true
        WriteText("Primary endpoint '$($currentPrimaryEndpoint.Name)' status is '$($currentPrimaryEndpoint.EndpointMonitorStatus)', proceeding with failover...")
        WriteSuccess
        break;
    }

    WriteText("Primary endpoint '$($currentPrimaryEndpoint.Name)' not '$($onlineMonitorStatus)' yet, its status is '$($currentPrimaryEndpoint.EndpointMonitorStatus)', waiting $($waitTimeIntervalMs) ms (retry = $($i))...")
    Start-Sleep -Milliseconds $waitTimeIntervalMs
    WriteText
}

# Ensures the primary endpoint is online in order to proceed
if ($primaryEndpoint -eq $null)
{
    WriteError("Primary endpoint $($TrafficManagerPrimaryEndpointName) is not online. Exiting...")
    return -1
}

# Disable secondary endpoints and set their weights to 1
for ($i=0; $i -lt $profile.Endpoints.Count; $i++)
{
    $endpoint = $profile.Endpoints[$i]

    if ($endpoint.Name.Equals($TrafficManagerPrimaryEndpointName, [System.StringComparison]::InvariantCultureIgnoreCase))
    {
        continue
    }
    Else
    {
        $endpoint.EndpointStatus = $disabledStatus
        $endpoint.Weight = 1

        WriteText("Updating SECONDARY endpoint '$($endpoint.Name)' => Status = $($endpoint.EndpointStatus); Weight = $($endpoint.Weight);...")       
        Set-AzureRmTrafficManagerEndpoint -TrafficManagerEndpoint $endpoint -ErrorAction Stop
        WriteSuccess
    }
}


# Failover - CosmosDB/DocumentDB ---------------------------------------->
WriteTitle("FAILOVER - COSMOSDB/DOCUMENTDB")
WriteText("Failing over CosmosDB/DocumentDB '$($DocumentDBAccountName)' from region '$($DocumentDBPrimaryLocation)' to '$($DocumentDBSecondaryLocation)'...")

$failoverPolicies = @(@{"locationName"="$($DocumentDBSecondaryLocation)"; "failoverPriority" = 0},@{"locationName"="$($DocumentDBPrimaryLocation)"; "failoverPriority" = 1})
Invoke-AzureRmResourceAction -Action failoverPriorityChange -ResourceType "Microsoft.DocumentDb/databaseAccounts" -ApiVersion "2015-04-08" -ResourceGroupName $DocumentDBResourceGroupName -Name $DocumentDBAccountName -Parameters @{"failoverPolicies"=$failoverPolicies} -Force -ErrorAction Stop 
WriteSuccess


return 0