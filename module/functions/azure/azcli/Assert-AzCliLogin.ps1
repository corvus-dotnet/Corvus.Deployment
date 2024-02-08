# <copyright file="Assert-AzCliLogin.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures a valid login to the azure-cli.

.DESCRIPTION
Verifies you have a valid azure-cli access token or prompts for an interactive login.

For automation scenarios, the azure-cli credentials can be passed via environment variables:
  AZURE_CLIENT_ID
  AZURE_CLIENT_SECRET

.PARAMETER SubscriptionId
The target Azure Subscription ID.

.PARAMETER AadTenantId
The AzureAD Tenant ID associated with subscription.

.PARAMETER TenantOnly
When true, the connection will not be attached to a subscription. This is useful when working with
identities that have no permissions to Azure resources (e.g. used only for Azure Active Directory automation).

.OUTPUTS
Returns the details of the logged-in account (i.e. the output from 'az account show').

#>
function Assert-AzCliLogin {
    [CmdletBinding(DefaultParameterSetName="Default")]
    param (
        [Parameter(ParameterSetName="Default", Mandatory=$true)]
        [string] $SubscriptionId,

        [Parameter(Mandatory=$true)]
        [string] $AadTenantId,

        [Parameter(ParameterSetName="TenantOnly", Mandatory=$true)]
        [switch] $TenantOnly
    )

    try {
        # check whether already logged-in
        if ($TenantOnly) {
            [datetime]$currentTokenExpiry = & az account get-access-token -o tsv --query "expiresOn" 2>&1
        }
        else {
            [datetime]$currentTokenExpiry = & az account get-access-token --subscription $SubscriptionId -o tsv --query "expiresOn" 2>&1
        }
        
        if ($currentTokenExpiry -le [datetime]::Now) {
            throw
        }
    }
    catch {
        $requiredEnvVarsForAutoLogin = (
            ![string]::IsNullOrEmpty($env:AZURE_CLIENT_ID) -and `
            ![string]::IsNullOrEmpty($env:AZURE_CLIENT_SECRET)
        )
        # login with the typical environment variables, if available
        if ($requiredEnvVarsForAutoLogin) {
            Write-Host "Performing azure-cli login as service principal via environment variables"
            $azCliParams = @(
                "--service-principal"
                "-u", $env:AZURE_CLIENT_ID
                "-p", "`"$($env:AZURE_CLIENT_SECRET)`""
                "--tenant", $AadTenantId
            )
            if ($TenantOnly) {
                $azCliParams += "--allow-no-subscriptions"
            }

            # The escaping we do above is incompatible with the revised argument parsing logic in
            # PowerShell v7.3+ (when running on non-Windows). Temporarily revert to the legacy
            # argument parsing mode to ensure we remain compatible with all PowerShell versions.
            # The override will fall out of scope when this function returns.
            $PSNativeCommandArgumentPassing = "Legacy"
            & az login @azCliParams
            if ($LASTEXITCODE -ne 0) {
                throw "Service Principal login to Azure CLI failed - check previous output."
            }
        }
        # Azure pipeline processes seem to report themselves as interactive - at least on linux agents
        elseif ( [Environment]::UserInteractive -and !(Test-Path env:\SYSTEM_TEAMFOUNDATIONSERVERURI) ) {
            & az login --tenant $AadTenantId
            if ($LASTEXITCODE -ne 0) {
                throw "Manual login to Azure CLI failed - check previous output."
            }
        }
        else {
            throw "When running non-interactively the process must already be logged-in to the Azure-cli or have the SPN details setup in environment variables"
        }
    }

    if (!$TenantOnly) {
        Invoke-AzCli "account set --subscription $SubscriptionId" -SuppressConnectionValidation
    }
    return (Invoke-AzCli "account show" -asJson -SuppressConnectionValidation)
}