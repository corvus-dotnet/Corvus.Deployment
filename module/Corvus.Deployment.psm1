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

.PARAMETER AadTenantId
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

# This will track whether the current session has explicitly connected to a tenant/subscription
$script:moduleContext = @{
	SubscriptionId = $null
	AadTenantId = $null
	AzPowerShell = @{
		Connected = $false
	}
	AzureCli = @{
		Connected = $false
	}
}

# Validate the Azure connection details only if the details have been specified 
if ($SubscriptionId -and $AadTenantId) {
	Connect-Azure -SubscriptionId $SubscriptionId -AadTenantId $AadTenantId
}
else {
	Write-Host "The current Azure connection details have not been validated - use 'Connect-CorvusAzure' to get connected."
}

# define some useful globals / constants
$script:AadGraphApiResourceId = "https://graph.windows.net/"