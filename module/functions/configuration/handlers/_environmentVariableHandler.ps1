# <copyright file="_environmentVariableHandler.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Implements the handler for resolving Environment Variable references.

.DESCRIPTION
Implements the handler for resolving Environment Variable references.

.PARAMETER ValueToResolve
The Environment Variable to be resolved.

#>
function _environmentVariableHandler {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        $ValueToResolve
    )

    if (Test-Path env:/$ValueToResolve){
        return (Get-Item env:/$ValueToResolve | Select-Object -ExpandProperty Value)
    }
    else {
        throw "Unable to resolve Environment Variable: $ValueToResolve"
    }
}

# Register this handler with _ResolveDeploymentConfigValues
[array]$script:configHandlers += @{
    name = "EnvironmentVariable"
    matcher = "@EnvironmentVariable\((?<valueToResolve>.*)\)"
    handler = "_environmentVariableHandler"
}