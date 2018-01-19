<#
.SYNOPSIS
    Adds a load balancer rule for the ActiveMQ management portal to an existent Load Balancer
.DESCRIPTION
    Adds a load balancer rule for the ActiveMQ management portal to an existent Load Balancer

    * Assumptions:
        - The ActiveMQ 5.15.2 management portal default port is 8161 and it is the desired port;
.NOTES
    File Name  : Add-ActiveMQManagementPortalRule.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\Add-ActiveMQManagementPortalRule.ps1 -SubscriptionId "d8d4aace-ad5f-468c-ac9e-bfb39a832229" -ResourceGroupName "rg" -LoadBalancerName "lb"
#>


Param (
    [Parameter(Mandatory=$true)]
    [String]
    $SubscriptionId,

    [Parameter(Mandatory=$true)]
    [String]
    $ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [String]
    $LoadBalancerName
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
WriteTitle("SUBSCRIPTION SELECTION")
WriteText("Setting subscription context...")
Select-AzureRmSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop
WriteSuccess


# Load Balancer --------------------------------------------------------->
WriteTitle("LOAD BALANCER")
WriteText("Loading full load balancer '$($LoadBalancerName)' details...")

# Loads full load balance data
$loadBalancer = Get-AzureRmLoadBalancer -Name $LoadBalancerName -ResourceGroupName $ResourceGroupName -ErrorAction Stop

if ($loadBalancer -eq $null)
{
    WriteError("No load balancer name '($($LoadBalancerName))' was found on resource group '$($ResourceGroupName)'...")
    return -1
}

WriteSuccess

$activeMQManagementPortalRuleName = "ActiveMQPortal" # default port 8161
$activeMQTcpRuleName = "ActiveMQTcp"  # default port 61616
$activeMQAmqpRuleName = "ActiveMQAmqp" # default port 5672

$addActiveMQManagementPortalRuleName = $true
$AddActiveMQTcpRuleName = $true
$addActiveMQAmqpRuleName = $true

# Checks if rule already exists (case insensitive)
foreach ($loadBalancingRule in $loadBalancer.LoadBalancingRules)
{
    WriteText($loadBalancingRule.Name)

    # Management Portal
    if ($loadBalancingRule.Name.Equals($activeMQManagementPortalRuleName, [System.StringComparison]::InvariantCultureIgnoreCase))
    {
        WriteText("Load balancer rule '$($loadBalancingRule.Name)' already exists. Skip adding this rule...")
        $addActiveMQManagementPortalRuleName = $false
    }

    # TCP
    if ($loadBalancingRule.Name.Equals($activeMQTcpRuleName, [System.StringComparison]::InvariantCultureIgnoreCase))
    {
        WriteText("Load balancer rule '$($activeMQTcpRuleName.Name)' already exists. Skip adding this rule...")
        $AddActiveMQTcpRuleName = $false
    }

    # AMQP
    if ($loadBalancingRule.Name.Equals($activeMQAmqpRuleName, [System.StringComparison]::InvariantCultureIgnoreCase))
    {
        WriteText("Load balancer rule '$($activeMQAmqpRuleName.Name)' already exists. Skip adding this rule...")
        $AddActiveMQAmqpRuleName = $false
    }
}

# Adds ActiveMQ Management Portal load balancing rule
if ($addActiveMQManagementPortalRuleName -eq $true)
{
    WriteText("Adding rule '$($activeMQManagementPortalRuleName)' load balancer '$($loadBalancer.Name)' details...")
    Add-AzureRmLoadBalancerRuleConfig -Name $activeMQManagementPortalRuleName -LoadBalancer $loadBalancer -FrontendIpConfiguration $loadBalancer.FrontendIpConfigurations[0] -BackendAddressPool $loadBalancer.BackendAddressPools[0] -Protocol Tcp -FrontendPort 8161 -BackendPort 8161 -ErrorAction Stop
    WriteSuccess
}

# Adds ActiveMQ TCP load balancing rule
if ($AddActiveMQTcpRuleName -eq $true)
{
    WriteText("Adding rule '$($activeMQTcpRuleName)' load balancer '$($loadBalancer.Name)' details...")
    Add-AzureRmLoadBalancerRuleConfig -Name $activeMQTcpRuleName -LoadBalancer $loadBalancer -FrontendIpConfiguration $loadBalancer.FrontendIpConfigurations[0] -BackendAddressPool $loadBalancer.BackendAddressPools[0] -Protocol Tcp -FrontendPort 61616 -BackendPort 61616 -ErrorAction Stop
    WriteSuccess
}

# Adds ActiveMQ AMQP load balancing rule
if ($AddActiveMQAmqpRuleName -eq $true)
{
    WriteText("Adding rule '$($activeMQAmqpRuleName)' load balancer '$($loadBalancer.Name)' details...")
    Add-AzureRmLoadBalancerRuleConfig -Name $activeMQAmqpRuleName -LoadBalancer $loadBalancer -FrontendIpConfiguration $loadBalancer.FrontendIpConfigurations[0] -BackendAddressPool $loadBalancer.BackendAddressPools[0] -Protocol Tcp -FrontendPort 5672 -BackendPort 5672 -ErrorAction Stop
    WriteSuccess
}

# Updates the load balancer
WriteText("Updating load balancer '$($loadBalancer.Name)' details...")
Set-AzureRmLoadBalancer -LoadBalancer $loadBalancer
WriteSuccess


return 0