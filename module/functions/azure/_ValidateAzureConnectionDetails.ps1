function _ValidateAzureConnectionDetails
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $SubscriptionId,

        [Parameter(Mandatory=$true)]
        [string] $AadTenantId,

        [Parameter()]
        [switch] $AzPowerShell,

        [Parameter()]
        [switch] $AzureCli
    )

    if ($AzPowerShell) {
        # Ensure PowerShell Az is connected with the details that have been provided
        $azContext = Get-AzContext
        if ($azContext.Subscription.Id -eq $SubscriptionId -and `
                $azContext.Tenant.Id -eq $AadTenantId
        ) {
            return $true
        }
        else {
            Write-Warning "SubscriptionId: Specified [$SubscriptionId], Actual [$($azContext.Subscription.Id)]"
            Write-Warning "TenantId      : Specified [$AadTenantId], Actual [$($azContext.Tenant.Id)]"
            return $false
        }
    }

    if ($AzureCli) {
        # Ensure PowerShell Az is connected with the details that have been provided
        $currentAccount = Assert-AzCliLogin -SubscriptionId $SubscriptionId -AadTenantId $AadTenantId

        if ($currentAccount.id -eq $SubscriptionId -and `
                $currentAccount.tenantId -eq $AadTenantId
        ) {
            return $true
        }
        else {
            Write-Warning "SubscriptionId: Specified [$SubscriptionId], Actual [$($currentAccount.id)]"
            Write-Warning "TenantId      : Specified [$AadTenantId], Actual [$($currentAccount.tenantId)]"
            return $false
        }
    }
}