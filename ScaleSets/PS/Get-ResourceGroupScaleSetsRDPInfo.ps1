<#
.SYNOPSIS
    Gets Scale Set RDP information (PublicIP:PortNumber)
.DESCRIPTION
    Gets Scale Set RDP information (PublicIP:PortNumber)
.NOTES
    File Name  : Get-ResourceGroupScaleSetsRDPInfo.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\Get-ResourceGroupScaleSetsRDPInfo.ps1 -SubscriptionId "d8d4aace-ad5f-468c-ac9e-bfb39a832229" -ResourceGroupName "rg"
#>


Param (
    [Parameter(Mandatory=$true)]
    [String]
    $SubscriptionId,

    [Parameter(Mandatory=$true)]
    [String]
    $ResourceGroupName
)


# Modules --------------------------------------------------------------->
Import-Module AzureRM.Resources


# Helper Functions ------------------------------------------------------>
. ..\..\Common\PS\Util.ps1


function GetNextToken
{
    Param
    (
        [Parameter(Mandatory=$true)]
        $Str,

        [Parameter(Mandatory=$true)]
        [String]
        $SplitCharacter,

        [Parameter(Mandatory=$true)]
        [String]
        $TokenName,

        [Parameter(Mandatory=$true)]
        [String]
        $UnableToGetTokensErrorMessage,

        [Parameter(Mandatory=$true)]
        [String]
        $UnableToGetNameErrorMessage
    )

    $tokens = $Str.Split($SplitCharacter)
    
    if ($tokens -eq $null)
    {
        WriteError($UnableToGetTokensErrorMessage)
        return -1
    }

    $name = $null
    for ($i = 0; $i -lt $tokens.Count; $i++)
    {
        if ($tokens[$i].Equals($TokenName, [System.StringComparison]::InvariantCultureIgnoreCase))
        {
            $i++
            $name = $tokens[$i]
            break
        }
    }

    if ($name -eq $null)
    {
        WriteError($UnableToGetNameErrorMessage)
        return -1
    }

    return $name
}

function GetScaleSetName
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]
        $BackendIpConfigurationId
    )

    $splitCharacter = "/"

    return GetNextToken -Str $BackendIpConfigurationId -SplitCharacter $splitCharacter -TokenName "virtualMachineScaleSets" -UnableToGetTokensErrorMessage "Unable to retrieve the scale set name since no tokens based on qualifier '$($splitCharacter)' were found..." -UnableToGetNameErrorMessage "Unable to retrieve the scale set name from the tokens..."
}

function GetPublicIpName
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]
        $PublicIpId
    )

    $splitCharacter = "/"

    return GetNextToken -Str $PublicIpId -SplitCharacter $splitCharacter -TokenName "publicIPAddresses" -UnableToGetTokensErrorMessage "Unable to retrieve the public IP name since no tokens based on qualifier '$($splitCharacter)' were found..." -UnableToGetNameErrorMessage "Unable to retrieve the public IP name because it is null, empty or whitespace..."
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


# Get Network Interface Data for Scale Set ------------------------------>
WriteTitle("LOAD BALANCER")
WriteText("Finding all load balancers on resource group '$($ResourceGroupName)'...")

# Find ALL load balancers within the resource group
$loadBalancers = Find-AzureRmResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.Network/loadBalancers"

if ($loadBalancers -eq $null)
{
    WriteText("No load balancer was found on resource group '$($ResourceGroupName)'...")
    return 0
}

WriteSuccess

# Iterates through found load balancers gathering RDP network information
foreach ($currentLoadBalancer in $loadBalancers)
{
    WriteText("Loading full load balancer '$($currentLoadBalancer.Name)' details...")

    # Loads full load balance data
    $loadBalancer = Get-AzureRmLoadBalancer -Name $currentLoadBalancer.Name -ResourceGroupName $ResourceGroupName -ErrorAction Stop

    if ($loadBalancer.BackendAddressPools -eq $null -or $loadBalancer.BackendAddressPools.Count -eq 0)
    {
        WriteError("Unable to retrieve the scale set name because there are no backend pools available...")
        return -1;
    }

    if ($loadBalancer.BackendAddressPools[0].BackendIpConfigurations -eq $null -or $loadBalancer.BackendAddressPools[0].BackendIpConfigurations.Count -eq 0)
    {
        WriteError("Unable to retrieve the scale set name because there are no backend pools IP configuration available...")
        return -1;
    }

    WriteSuccess

    # Retrieves the scale set name
    $scaleSetName = GetScaleSetName($loadBalancer.BackendAddressPools[0].BackendIpConfigurations[0].Id) -ErrorAction Stop
    WriteSubtitle("RDP details for scale set '$($scaleSetName)'")

    # Gets the Public IP name
    $publicIpName = GetPublicIpName($loadBalancer.FrontendIpConfigurations[0].PublicIpAddress.Id)

    # Loads Public IP object
    $publicIp = Get-AzureRmPublicIpAddress -Name $publicIpName -ResourceGroupName $ResourceGroupName

    for ($j = 0; $j -lt $loadBalancer.InboundNatRules.Count; $j++)
    {
        $currentInboundRule = $loadBalancer.InboundNatRules[$j]
        WriteText("$($currentInboundRule.Name) => $($publicIp.IpAddress):$($currentInboundRule.FrontendPort)")
    }

    WriteSuccess
}


return 0