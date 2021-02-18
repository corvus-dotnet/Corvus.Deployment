# <copyright file="Assert-Module.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that the specfied module is available.

.DESCRIPTION
Checks the presence of the specfied module version, installing it if necessary.

.PARAMETER Name
The module name.

.PARAMETER Version
The module version.

.PARAMETER AdditionalArgs
Any additional 'Install-Module' arguments required by the module (e.g. -AcceptLicense)

.PARAMETER DoNotInstall
Suppresses the auto-install behaviour

.PARAMETER Scope
Sets the installation scope of the module.

.PARAMETER PSRepository
Sets the PowerShell repository used as the source (e.g. PSGallery)

.OUTPUTS
Returns the 'PSModuleInfo' object for the asserted module - this can be used by the caller to easily import the module.

#>
function Assert-Module
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [string] $Name,

        [Parameter()]
        [string] $Version = "Latest",

        [Parameter()]
        [hashtable] $AdditionalArgs,

        [Parameter()]
        [switch] $DoNotInstall,

        [Parameter()]
        [string] $Scope = "CurrentUser",

        [Parameter()]
        [string] $PSRepository = "PSGallery"
    )

    $existingLoaded = Get-Module $Name
    $existingInstalled = Get-Module -ListAvailable $Name

    # TODO: a version unconstrained check

    if ($null -ne $existingLoaded -and $existingLoaded.Version -eq $Version) {
        return $existingLoaded
    }
    elseif ($existingLoaded) {
        Write-Verbose ("Unloading incorrect version of module {0} - (actual={1}, required={2})" -f $Name, $existingLoaded.Version, $Version)
        $existingLoaded | Remove-Module -Verbose:$false
    }

    if ($DoNotInstall) {
        throw "The required module {0} v{1} is not available and was not installed due to DoNotInstall=true"
    }

    if ($null -eq $existingInstalled -or ($Version -notin $existingInstalled.Version)) {
        Write-Verbose ("Installing required module: {0} v{1}" -f $Name, $Version)
        $installArgs= @{
            Name = $Name
            Scope = $Scope
            Force = $true
            RequiredVersion = $Version
            Repository = $PSRepository
        }
        if ($AdditionalArgs) {
            $installArgs += $AdditionalArgs
        }
        Install-Module @installArgs
    }

    $assertedModule = Get-Module -ListAvailable $Name | Where-Object { $_.Version -eq $Version }
    if (!$assertedModule) {
        throw "The module {0} v{1} was unexpectedly not available"
    }
    return $assertedModule
}