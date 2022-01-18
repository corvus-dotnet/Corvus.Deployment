# <copyright file="Assert-AzdoServiceConnection.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that an Azure DevOps service connection exists for the specified project.

.DESCRIPTION
Sets up an AzureRM-style service connection inside Azure DevOps and will create a suitable AAD service principal
if necessary. The secret for a created service principal never leaves this script.

NOTE: When a service principal already exists but the service connection does not, the secret on the service
principal will be reset in order to make it available to the Azure DevOps service connection registration
process.

.PARAMETER Name
The name of the service connection.

.PARAMETER Project
The name of the Azure DevOps project.

.PARAMETER Organisation
The name of the Azure DevOps organisation.

.PARAMETER ServicePrincipalName
The Service Principal Name of the AAD identity that the service connection should use. When omitted,  
defaults to the same as the service connection.

.PARAMETER AllowSecretReset
When specified, pre-existing service principals will have their credential reset so it is available to
Azure DevOps when creating the service connection.  When not specified, this scenario will cause a
terminating error. 

.PARAMETER SubscriptionId
The default subscription associated with the service connection.

.PARAMETER AadTenantId
The default Azure tenant associated with the service connection.

.OUTPUTS
Returns a hashtable representing the JSON object describing the service connection.

#>

function Assert-AzdoServiceConnection
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $Project,

        [Parameter(Mandatory=$true)]
        [string] $Organisation,

        [Parameter()]
        [guid] $SubscriptionId,

        [Parameter()]
        [guid] $AadTenantId,

        [Parameter()]
        [string] $ServicePrincipalName,

        [Parameter()]
        [switch] $AllowSecretReset
    )

    _EnsureAzureConnection -AzureCli | Out-Null
    
    $ServicePrincipalName ??= $Name
    $SubscriptionId ??= $moduleContext.SubscriptionId
    $subscriptionName = (Get-AzSubscription -SubscriptionId $SubscriptionId).Name
    $AadTenantId ??= $moduleContext.AadTenantId

    $orgUrl = Get-AzdoOrganisationUrl $Organisation

    $serviceConnectionType = "azurerm"

    Assert-AzureCliExtension -Name "azure-devops" | Out-Null

    $lookupArgs = @(
        "devops service-endpoint list"
        "--organization `"$orgUrl`""
        "--project `"$Project`""
        "--query `"[?type=='$serviceConnectionType' && name=='$Name']`""
    )
    $existingAdoServiceConnection = Invoke-AzCli $lookupArgs -asJson

    if (!$existingAdoServiceConnection) {
        Write-Host "A new ADO service connection will be created"
        $existingSp,$spSecret = Assert-AzureServicePrincipalForRbac -Name $ServicePrincipalName `
                                                                    -WhatIf:$WhatIfPreference
        
        # check we have the secret for the SPN
        if (!$spSecret -and $AllowSecretReset) {
            if ($PSCmdlet.ShouldProcess($Name, "Reset Service Principal Credential")) {
                Write-Warning "The service principal already exists, but the secret is not available.  The secret will be reset as '-AllowSecretReset' was specified"
    
                $resetSecretArgs = @(
                    "ad sp credential reset"
                    "--name $($existingSp.appId)"
                )
                $updatedSp = Invoke-AzCli $resetSecretArgs -asJson
                $spSecret = $updatedSp.password
            }
        }
        elseif (!$spSecret) {
            throw "The service principal already exists, but the secret is not available.  To reset the secret specify the '-AllowSecretReset' parameter."
        }

        # register ADO service connection
        if ($PSCmdlet.ShouldProcess($Project, "Create Service Connection")) {
            $createArgs = @(
                "devops service-endpoint azurerm create"
                "--name $Name"
                "--azure-rm-service-principal-id $($existingSp.appId)"
                "--azure-rm-subscription-id $SubscriptionId"
                "--azure-rm-subscription-name `"$subscriptionName`""
                "--azure-rm-tenant-id $AadTenantId"
                "--organization `"$orgUrl`""
                "--project `"$Project`""
            )

            $env:AZURE_DEVOPS_EXT_AZURE_RM_SERVICE_PRINCIPAL_KEY = $spSecret
            Write-Host "Registering new ADO Service Connection..."
            $existingAdoServiceConnection = Invoke-AzCli $createArgs -asJson
            $env:AZURE_DEVOPS_EXT_AZURE_RM_SERVICE_PRINCIPAL_KEY = $null
        }
    }
    else {
        Write-Host "ADO Service Connection already exists - skipping"
    }

    return $existingAdoServiceConnection
}