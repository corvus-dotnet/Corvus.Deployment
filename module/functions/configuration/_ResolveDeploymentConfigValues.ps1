# <copyright file="_ResolveDeploymentConfigValues.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Detects whether any configuration values need to be resolved by a handler.

.DESCRIPTION
Detects whether any configuration values need to be resolved by a handler.

.PARAMETER DeploymentConfig
A hashtable containing the configuration key/value pairs.

#>
function _ResolveDeploymentConfigValues {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable] $DeploymentConfig
    )

    for ($i=0; $i -lt $DeploymentConfig.Keys.Count; $i++) {
        $key = $DeploymentConfig.Keys | Select-Object -Skip $i -First 1
        Write-Verbose "Checking resolvers for '$key'"
        $configValue = $DeploymentConfig[$key]

        foreach ($resolver in $configHandlers) {
            Write-Verbose "Checking resolver: '$($resolver.name)'"
            $handlerRes = [regex]::Matches($configValue, $resolver.matcher)
            if ($handlerRes.Count -gt 0) {
                Write-Verbose "Matched resolver: '$($resolver.name)'"
                $DeploymentConfig[$key] = _invokeHandler -HandlerName $resolver.handler `
                                                         -ValueToResolve $handlerRes[0].Groups['valueToResolve'].Value
                break
            }
        }
    }

    return $DeploymentConfig
}


function _invokeHandler {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $HandlerName,
        [Parameter(Mandatory=$true)]
        [string] $ValueToResolve
    )

    & $HandlerName $ValueToResolve
}

# Dynamically load the discovered configuration handlers
$private:here = Split-Path -Parent $PSCommandPath
$script:configHandlers = @()
foreach ($handler in (Get-ChildItem $here/handlers/*.ps1)) {
    . $handler.FullName
}

