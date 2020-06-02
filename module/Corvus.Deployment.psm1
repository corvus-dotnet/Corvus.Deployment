# <copyright file="Corvus.Deployment.psm1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Contains a collection of useful utilities, templates and conventions for Azure deployment automation.

.DESCRIPTION
Contains a collection of useful utilities, templates and conventions for Azure deployment automation.

.PARAMETER SubscriptionId
The Azure Subscription that will be used for any Azure operations.

.PARAMETER SubscriptionId
The Azure Tenant that the Subscription belongs to.
#>

param
(
	[Parameter(Mandatory=$true)]
	$SubscriptionId,

	[Parameter(Mandatory=$true)]
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

# Ensure PowerShell Az is logged-in
if ($null -eq (Get-AzContext) -and [Environment]::UserInteractive) {
	Connect-AzAccount -Subscription $SubscriptionId -Tenant $AadTenantId
}
elseif ($null -eq (Get-AzContext)) {
	Write-Error "When running non-interactively the process must already be logged-in to the Az PowerShell modules"
}

# Ensure we're connected to the correct subscription
Set-AzContext -SubscriptionId $SubscriptionId -TenantId $AadTenantId | Out-Null


# define some useful globals / constants
$script:AzContext = Get-AzContext
$script:AadTenantId = $AadTenantId
$script:AadGraphApiResourceId = "https://graph.windows.net/"