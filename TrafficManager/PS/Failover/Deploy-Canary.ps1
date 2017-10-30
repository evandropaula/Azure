<#
.SYNOPSIS
    Failover Traffic Manager incrementally to support canary deployments
.DESCRIPTION
    Failover Traffic Manager incrementally to support canary deployments

    * Premises:
        - Service is running in two distinct regions in Azure (e.g. East US and West US);
        - Azure Traffic Manager is used to manage incoming traffic between the two regions;
        - CosmosDB/DocumentDB is the data store with geo-replication enabled (e.g. East US (R/W) and West US (RO));

    * Assumptions:
        - Azure Traffic Manager if configured as:
            - Routing Method = Weighted;
            - Number of Endpoints = 2;
            - Only one of the endpoints is enabled;
            - Weight for endpoint 1 (enabled) = 100;
            - Weight for endpoint 1 (disabled) = 1;
        - Traffic will use the following incremental constants to while failing over traffic: 5, 25, 50, 75, 100
            - This is not parameterized due to the assumption to provide a consistent deployment behavior across multiple groups within the organization;
            - Organizations with high software engineering maturity may override this implementation if the tradeoffs for each scenario are well understood;

    * Known Limitation:
        - CosmosDB has a threshold limit for failover requests, which leads to the following error if you failover too many times within a short amount of time:
            Invoke-AzureRmResourceAction : {"code":"PreconditionFailed","message":"Rate of write region change request exceeded maximum allowed rate.
            Please retry this request after 44 mins.\r\nActivityId: d8da8f27-333e-46e8-a6fa-13409f3af48c"}
        - To get rid of this threshold, file a support ticket to the Azure CosmosDB team through the Azure Portal. This is recommended specially for test and production environment;
.NOTES
    File Name  : Deploy-Canary.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\Deploy-Canary.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -TenantId "e6e208d1-2717-49da-8ad9-982b68b1308f" -ResourceGroupName "rg" -TrafficManagerProfileName "tmp" -DocumentDBResourceGroupName "rg" -DocumentDBAccountName "docdb" -DocumentDBPrimaryLocation "West US" -DocumentDBSecondaryLocation "East US"
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
    $ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [String]
    $TrafficManagerProfileName,

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
$onlineMonitorStatus = "Online"
$primaryWeights = @(95, 75, 50, 25, 1)
$secondaryWeights = @(5, 25, 50, 75, 100)


# Helper Functions ------------------------------------------------------>
function Rollback
{
    Param
    (
        $primaryEndpoint,
        $secondaryEndpoint
    )
    
    WriteError("***************************")
    WriteError("***** R O L L B A C K *****")
    WriteError("***************************")
    
    # Enabled primary endpoint
    WriteText("Enabling primary endpoint '$($primaryEndpoint.Name)'...")
    $primaryEndpoint.EndpointStatus = $enabledStatus
    $primaryEndpoint.Weight = 100
    Set-AzureRmTrafficManagerEndpoint -TrafficManagerEndpoint $primaryEndpoint -ErrorAction Stop
    WriteSuccess

    # Disable secondary endpoint
    WriteText("Disabling secondary endpoint '$($secondaryEndpoint.Name)'...")
    $secondaryEndpoint.EndpointStatus = $disabledStatus
    $secondaryEndpoint.Weight = 1
    Set-AzureRmTrafficManagerEndpoint -TrafficManagerEndpoint $secondaryEndpoint -ErrorAction Stop
    WriteSuccess

    # Ensure CosmosDB/DocumentDB primary and secondary remain the same
    WriteText("Ensuring CosmosDB/DocumentDB primary is '$($DocumentDBPrimaryLocation)' and secondary is '$($DocumentDBSecondaryLocation)'...")
    $failoverPolicies = @(@{"locationName"="$($DocumentDBPrimaryLocation)"; "failoverPriority" = 0},@{"locationName"="$($DocumentDBSecondaryLocation)"; "failoverPriority" = 1})
    Invoke-AzureRmResourceAction -Action failoverPriorityChange -ResourceType "Microsoft.DocumentDb/databaseAccounts" -ApiVersion "2015-04-08" -ResourceGroupName $DocumentDBResourceGroupName -Name $DocumentDBAccountName -Parameters @{"failoverPolicies"=$failoverPolicies} -Force -ErrorAction Stop
    WriteSuccess
}


# Login to Azure -------------------------------------------------------->
WriteTitle("AUTHENTICATION")
WriteText("Logging in to Azure...")
#Login-AzureRmAccount -ErrorAction Stop
WriteSuccess


# Set Context to Subscription Id ---------------------------------------->
WriteTitle("SUBSCRIPTION SELECTION")
WriteText("Setting subscription context...")
Select-AzureRmSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop
WriteSuccess


# Get Traffic Manager Profile ------------------------------------------->
WriteTitle("TRAFFIC MANAGER")
WriteText("Reading Traffic Manager Profile...")
$profile = Get-AzureRmTrafficManagerProfile -Name $TrafficManagerProfileName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
$profile
WriteSuccess


# Validate Asseumptions ------------------------------------------------->
WriteTitle("VALIDATIONS")
WriteText("Validating endpoints...")

# 2 is the expected amount of endpoints (e.g. East US and West US)
$expecteEncpointsCount = 2

if ($profile.Endpoints -eq $null)
{
    WriteError("There are no endpoints configured. Exiting...")
    return -1
}
ElseIf($profile.Endpoints.Count -ne $expecteEncpointsCount) 
{
    WriteError("Invalid amount of expected endpoints configured (Expected=$($expecteEncpointsCount); Actual = $($profile.Endpoints.Count)). Exiting...")
    return -1
}

# 2 is the expected amount of endpoints (e.g. East US and West US)
$isOneEndpointDisabled = ($profile.Endpoints[0].EndpointStatus -eq $disabledStatus  -or $profile.Endpoints[1].EndpointStatus -eq $disabledStatus)

If($isOneEndpointDisabled -eq $false) 
{
    WriteError("One the endpoints must be disabled. Exiting...")
    return -1
}

WriteSuccess


# Validate Assumptions -------------------------------------------------->
WriteTitle("PRIMARY & SECONDARY")
WriteText("Existing endpoints...")
$profile.Endpoints

$primaryEndpoint = $null
$secondaryEndpoint = $null

WriteText("Defining primary and secondary endpoints...")
if ($profile.Endpoints[1].EndpointStatus -eq $disabledStatus)
{
    $primaryEndpoint = $profile.Endpoints[0] # (e.g. East US)
    $secondaryEndpoint = $profile.Endpoints[1] # (e.g. West US)
}
Else
{
    $primaryEndpoint = $profile.Endpoints[1] # (e.g. West US)
    $secondaryEndpoint = $profile.Endpoints[0] # (e.g. East US)
}

WriteText("Primary endpoint is '$($primaryEndpoint.Name)'")
WriteText("Secondary endpoint is '$($secondaryEndpoint.Name)'")
WriteSuccess


# Failover -------------------------------------------------------------->
WriteTitle("FAILOVER")

# Enable secondary endpoint
WriteText("Enabling secondary endpoint...")
$secondaryEndpoint.EndpointStatus = "Enabled"
Set-AzureRmTrafficManagerEndpoint -TrafficManagerEndpoint $secondaryEndpoint -ErrorAction Stop
WriteSuccess

# Wait for the secondary endpoint to become online
WriteText("Waiting for the secondary endpoint to become '$($onlineMonitorStatus)'...")

# 5 minutes based on retry and wait time
$maxRetry = 30
$waitTimeIntervalMs = 10000
$isSecondaryEndpointOnline = $false

for ($i=0; $i -lt $maxRetry; $i++)
{
    $currentSecondaryEndpoint = Get-AzureRmTrafficManagerEndpoint -Name $secondaryEndpoint.Name -Type $secondaryEndpoint.Type -ProfileName $TrafficManagerProfileName -ResourceGroupName $ResourceGroupName -ErrorAction Continue -ErrorVariable err

    # Rollback if an error occurs
    if ($err.Count -gt 0)
    {
        Rollback $primaryEndpoint $secondaryEndpoint
        return -1
    }

    if ($currentSecondaryEndpoint.EndpointMonitorStatus -eq $onlineMonitorStatus)
    {
        WriteText("Secondary endpoint '$($currentSecondaryEndpoint.Name)' IS '$($currentSecondaryEndpoint.EndpointMonitorStatus)', proceeding with failover...")
        $isSecondaryEndpointOnline = $true
        break;
    }

    WriteText("Secondary endpoint '$($currentSecondaryEndpoint.Name)' status is '$($currentSecondaryEndpoint.EndpointMonitorStatus)', waiting $($waitTimeIntervalMs) ms (retry = $($i))...")
    Start-Sleep -Milliseconds $waitTimeIntervalMs

    WriteText
}

if ($isSecondaryEndpointOnline -eq $false)
{
    WriteText("Secondary endpoint '$($secondaryEndpoint.Name)' IS NOT '$($onlineMonitorStatus)', rolling back...")
    return -1
}

WriteSuccess

# Incremental failover (Traffic Manager and CosmosDB/DocumentDB)
$waitTimeIntervalMs = 120000

for ($i=0; $i -lt $primaryWeights.length; $i++)
{
    $primaryEndpoint.Weight = $primaryWeights[$i];
    WriteText("Setting '$($primaryEndpoint.Name)' weight to '$($primaryEndpoint.Weight)'...")
    Set-AzureRmTrafficManagerEndpoint -TrafficManagerEndpoint $primaryEndpoint -ErrorAction Stop -ErrorVariable err
    WriteSuccess

    # Rollback if an error occurs
    if ($err.Count -gt 0)
    {
        Rollback $primaryEndpoint $secondaryEndpoint
        return -1
    }

    $secondaryEndpoint.Weight = $secondaryWeights[$i];
    WriteText("Setting '$($secondaryEndpoint.Name)' weight to '$($secondaryEndpoint.Weight)'...")
    Set-AzureRmTrafficManagerEndpoint -TrafficManagerEndpoint $secondaryEndpoint -ErrorAction Stop -ErrorVariable err
    WriteSuccess

    # Rollback if an error occurs
    if ($err.Count -gt 0)
    {
        Rollback $primaryEndpoint $secondaryEndpoint
        return -1
    }

    # Failover CosmosDB/DocumentDB
    if ($secondaryEndpoint.Weight -eq 75)
    {
        WriteText("Failing over CosmosDB/DocumentDB '$($DocumentDBAccountName)' from region '$($DocumentDBPrimaryLocation)' to '$($DocumentDBSecondaryLocation)'...")
        $failoverPolicies = @(@{"locationName"="$($DocumentDBSecondaryLocation)"; "failoverPriority" = 0},@{"locationName"="$($DocumentDBPrimaryLocation)"; "failoverPriority" = 1})
        Invoke-AzureRmResourceAction -Action failoverPriorityChange -ResourceType "Microsoft.DocumentDb/databaseAccounts" -ApiVersion "2015-04-08" -ResourceGroupName $DocumentDBResourceGroupName -Name $DocumentDBAccountName -Parameters @{"failoverPolicies"=$failoverPolicies} -Force -ErrorAction Stop -ErrorVariable err  
        WriteSuccess

        # Rollback if an error occurs
        if ($err.Count -gt 0)
        {
            Rollback $primaryEndpoint $secondaryEndpoint
            return -1
        }
    }

    # Wait & Check Health
    if (($i + 1) -lt $primaryWeights.length)
    {
        WriteText("Waiting $($waitTimeIntervalMs) ms'...")
        Start-Sleep -Milliseconds $waitTimeIntervalMs
    }

    WriteText
}

# Disable primary endpoint
WriteText("Disabling primary endpoint...")
$primaryEndpoint.EndpointStatus = $disabledStatus
Set-AzureRmTrafficManagerEndpoint -TrafficManagerEndpoint $primaryEndpoint
WriteSuccess


return 0