# <copyright file="_keyVaultSecretUriHandler.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Implements the handler for resolving Key Vault SecretUri references.

.DESCRIPTION
Implements the handler for resolving Key Vault SecretUri references.

.PARAMETER ValueToResolve
The Key Vault Secret URI to be resolved.

#>
function _keyVaultSecretUriHandler {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        $ValueToResolve
    )

    # Check whether we have a valid AzPowerShell connection
    _EnsureAzureConnection -AzPowerShell -ErrorAction Stop | Out-Null

    if ($ValueToResolve -notmatch "\?api-version=") {
        $ValueToResolve = "$($ValueToResolve)?api-version=7.3"
    }
    $res = Invoke-AzRestMethod -Uri $ValueToResolve
    if ($res.StatusCode -eq 200) {
        $res.Content |
            ConvertFrom-Json | 
            Select-Object -ExpandProperty value |
            ConvertTo-SecureString -AsPlainText
    }
    else {
        throw "Unable to resolve Key Vault secret: $($res.Content)"
    }
}

# Register this handler with _ResolveDeploymentConfigValues
[array]$script:configHandlers += @{
    name = "KeyVaultSecretUri"
    matcher = "@Microsoft.KeyVault\(SecretUri=(?<valueToResolve>.*)\)"
    handler = "_keyVaultSecretUriHandler"
}