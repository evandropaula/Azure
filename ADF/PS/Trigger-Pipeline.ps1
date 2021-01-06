<#
.SYNOPSIS
    Trigger a pipeline N (default 1) amount of times.
.DESCRIPTION
    Trigger a pipeline N (default 1) amount of times.
.NOTES
    File Name  : Trigger-Pipeline.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\Trigger-Pipeline.ps1 -SubscriptionId "08649a91-b2a5-44e6-a382-a0559b0fa302" -TenantId "b2e79897-73ad-4494-a39b-d1e003603df4" -ResourceGroupName "ResourceGroupName" -DataFactoryName "AdfName" -PipelineName "Pipeline1"
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
    $DataFactoryName,

    [Parameter(Mandatory=$true)]
    [String]
    $PipelineName,

    [Parameter(Mandatory=$false)]
    [String]
    $NumberOfTimesToTrigger = 1
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
Set-AzureRmContext -SubscriptionId $SubscriptionId
WriteSuccess



# Trigger Pipeline ------------------------------------------------------>
WriteTitle("ADF Pipeline")

for ($i=1; $i -le $NumberOfTimesToTrigger; $i++)
{
    WriteText("Triggering pipeline '$($PipelineName)'...($($i))")

    $RunId = Invoke-AzureRmDataFactoryV2Pipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineName $PipelineName -ErrorAction Stop
    
    WriteText("Run Id -> $($RunId)...")

    $Run = Get-AzureRmDataFactoryV2PipelineRun -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineRunId $RunId -ErrorAction Stop

    WriteSuccess
}

return 0