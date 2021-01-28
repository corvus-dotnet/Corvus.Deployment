# <copyright file="Corvus.Deployment.psm1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Contains a collection of useful utilities, templates and conventions for Azure deployment automation.

.DESCRIPTION
Contains a collection of useful utilities, templates and conventions for Azure deployment automation.

.PARAMETER SubscriptionId
The Azure Subscription that is the default target for any Azure operations.

.PARAMETER SubscriptionId
The Azure Tenant that the Subscription belongs to.
#>

[CmdletBinding()]
param
(
	[Parameter(Position=0)]
	$SubscriptionId,

	[Parameter(Position=1)]
	$AadTenantId
)

$ErrorActionPreference = 'Stop'

# Dynamically populate the module
#
# NOTE:
#  1) Ignore any Pester test fixtures
#

# find all the functions that make-up this module
$functions = Get-ChildItem -Recurse $PSScriptRoot/functions -Include *.ps1 | `
								Where-Object { $_ -notmatch ".Tests.ps1" }
					
# dot source the individual scripts that make-up this module
foreach ($function in ($functions)) { . $function.FullName }

# export the non-private functions (by convention, private function scripts must begin with an '_' character)
Export-ModuleMember -function ( $functions | 
									ForEach-Object { (Get-Item $_).BaseName } | 
									Where-Object { -not $_.StartsWith("_") }
							)

# ensure PowerShell Az modules are available
$azAvailable = Get-Module Az -ListAvailable
if ($null -eq $azAvailable) {
	Write-Error "Az PowerShell modules are not installed - they can be installed using 'Install-Module Az -AllowClobber -Force'"
}

# Validate the Azure connection details only if the details have been specified 
if ($SubscriptionId -and $AadTenantId) {
	Write-Host "Validating Az PowerShell connection"
	# Ensure PowerShell Az is connected with the details that have been provided
	$azContext = Get-AzContext
	Write-Host "SubscriptionId: Specified [$SubscriptionId], Actual [$($azContext.Subscription.Id)]"
	Write-Host "TenantId      : Specified [$AadTenantId], Actual [$($azContext.Tenant.Id)]"
	if ($azContext.Subscription.Id -ne $SubscriptionId -or $azContext.Tenant.Id -ne $AadTenantId) {
		Write-Error "The current Az PowerShell connection context does not match the details provided when importing this module"
	}
}
else {
	Write-Host "The current Az PowerShell connection details have not been validated"
}

# define some useful globals / constants
$script:AadGraphApiResourceId = "https://graph.windows.net/"