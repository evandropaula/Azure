<#
.SYNOPSIS
    Login with a Service Principal account
.DESCRIPTION
    Login with a Service Principal account, which is useful when you want to double check if the key is indeed correct
.NOTES
    File Name  : Login-ServicePrincipal.ps1
    Author     : Evandro de Paula
.EXAMPLE
    .\Login-ServicePrincipal.ps1 -SubscriptionId "f4f718ef-c9ed-429c-9bb5-614c999b91d3" -TenantId "398e7a92-6e66-4ae1-8fe1-71564738f2df" -ServicePrincipalApplicationId "113b4921-b92d-431e-829b-1dc6f4b2f84e" -Password "Microsoft123"
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
    $Password
)


# Helper Functions ------------------------------------------------------>
. ..\..\Common\PS\Util.ps1


# Login to Azure -------------------------------------------------------->
WriteTitle("AUTHENTICATION")
WriteText("Logging in to Azure to test the Service Principal account...")

$securePassword = ConvertTo-SecureString $Password -asplaintext -force
$creds = New-Object System.Management.Automation.PSCredential ($ServicePrincipalApplicationId, $securePassword)
Add-AzureRmAccount -ServicePrincipal -Credential $creds -TenantId $TenantId -ErrorAction Stop

WriteSuccess


return 0