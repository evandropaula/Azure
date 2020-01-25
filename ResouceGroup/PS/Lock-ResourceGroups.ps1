<#
.SYNOPSIS
    Enable locking Azure Resource Groups to prevent accidental deletion and bigger consequences (e.g. outage).
.DESCRIPTION
    Enable locking Azure Resource Groups to prevent accidental deletion and bigger consequences (e.g. outage).
.NOTES
    File Name  : Lock-ResourceGroups.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\Lock-ResourceGroups.ps1 -SubscriptionId "81d52103-cd8d-419f-8e4f-1cb583abaecb" -TenantId "d6ce820e-babb-4938-a270-f8ba49771765"
    .\Lock-ResourceGroups.ps1 -SubscriptionId "81d52103-cd8d-419f-8e4f-1cb583abaecb" -TenantId "d6ce820e-babb-4938-a270-f8ba49771765" -ExclusionRegularExpression ".*rg"
#>

Param (
    [Parameter(Mandatory=$true)]
    [String]
    $SubscriptionId,

    [Parameter(Mandatory=$true)]
    [String]
    $TenantId,

    [Parameter(Mandatory=$false)]
    [String]
    $ExclusionRegularExpression
)


# Modules --------------------------------------------------------------->
Import-Module AzureRM.Resources


# Helper Functions ------------------------------------------------------>
Try
{
    . ..\..\Common\PS\Util.ps1
}
Catch [System.Management.Automation.CommandNotFoundException]
{
    # Ignoring errors in case the script has been ALREADY LOADED by the caller script in a different directory (e.g. .\platform-azure-foundation\CardFulfillment\Dev\EastUS\CreateSecrets.ps1)
}


# Login to Azure -------------------------------------------------------->
WriteTitle("AUTHENTICATION")
WriteText("Logging in to Azure...")
Login-AzureRmAccount
WriteSuccess


# Login to Azure -------------------------------------------------------->
WriteTitle("RESOURCE GROUPS")
WriteText("Locking resource groups...")

$resourceGroups = Get-AzureRmResourceGroup 

for ($i=0; $i -lt $resourceGroups.length; $i++)
{
    $resourceGroup = $resourceGroups[$i]

    $lock = Get-AzureRmResourceLock -ResourceGroupName $resourceGroup.ResourceGroupName

    if ($lock -eq $null)
    {
        if ([string]::IsNullOrWhiteSpace($ExclusionRegularExpression) -eq $false -and $resourceGroup.ResourceGroupName -match $ExclusionRegularExpression)
        {
            WriteText("Skkiping resource group '$($resourceGroup.ResourceGroupName)', which is EXCLUDED by regular expression.");
            WriteSuccess
            continue;
        }

        # Lock resource group
        WriteText("Resource group '$($resourceGroup.ResourceGroupName)' is NOT locked. Locking it...")
        $currentDateTime = Get-Date
        $lockNotes = "Locked on '$($currentDateTime)' by host '$($Env:COMPUTERNAME)'"
        $lockName = "Lock$($resourceGroup.ResourceGroupName)"

        New-AzureRmResourceLock -LockLevel "CanNotDelete" -LockNotes $lockNotes -LockName $lockName -ResourceName $resourceGroup.ResourceGroupName -ResourceType "Microsoft.Resources/resourceGroups" -ResourceGroupName $resourceGroup.ResourceGroupName -Force 
        
        WriteSuccess
    }
    else
    {
        WriteText("Resource group '$($resourceGroup.ResourceGroupName)' is ALREADY locked.")
    }
}

return 0