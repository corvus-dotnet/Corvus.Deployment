# <copyright file="Assert-AzureAdAppRole.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that an AzureAD application role with the specified configuration exists.

.DESCRIPTION
Ensures that an AzureAD application role with the specified configuration exists, creating or updating as necessary.

.PARAMETER AppObjectId
The object ID of the AzureAD application of which to add the role to.

.PARAMETER AppRoleId
Used to search for an existing AzureAD application role or create one with the specified name.

.PARAMETER DisplayName
The display name for the application role.

.PARAMETER Description
The description for the application role.

.PARAMETER Value
The value for the application role.

.PARAMETER AllowedMemberTypes
Allowed member types for the application (User / Application)

.PARAMETER Enabled
When true, the application is enabled for use otherwise it will not be usable.

.OUTPUTS
Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphApplication
#>
function Assert-AzureAdAppRole
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory=$true)]
        [string] $AppObjectId,

        [Parameter(Mandatory=$true)]
        [string] $AppRoleId,

        [Parameter(Mandatory=$true)]
        [string] $DisplayName,

        [Parameter(Mandatory=$true)]
        [string] $Description,

        [Parameter(Mandatory=$true)]
        [string] $Value,
        
        [Parameter(Mandatory=$true)]
        [string[]] $AllowedMemberTypes,

        [bool] $Enabled = $true
    )

    # Check whether we have a valid AzPowerShell connection, but no subscription-level access is required
    _EnsureAzureConnection -AzPowerShell -TenantOnly -ErrorAction Stop | Out-Null

    $app = Get-AzADApplication -Id $AppObjectId

    # Check whether the AppRole is already defined
    $appRole = $app.AppRole | Where-Object { $_.id -eq $AppRoleId }
    
    # Prepare an AppRole object using the supplied values
    $appRoleFromParams = @{
        displayName = $DisplayName
        id = $AppRoleId
        isEnabled = $Enabled
        description = $Description
        value = $Value
        allowedMemberType = $AllowedMemberTypes
    }

    # Idempotency logic to decide whether an update is required
    $doUpdate = $true
    if ($appRole) {
        $compareResult = Compare-Object -ReferenceObject $appRole `
                                        -DifferenceObject $appRoleFromParams `
                                        -Property ([array]$appRoleFromParams.Keys)
        if ($compareResult) {
            Write-Host "AppRole '$Value': UPDATING"
            $appRole.displayName = $DisplayName
            $appRole.isEnabled = $Enabled
            $appRole.description = $Description
            $appRole.value = $Value
            $appRole.allowedMemberType = $AllowedMemberTypes
        }
        else {
            Write-Host "AppRole '$Value': NO CHANGES"
            $doUpdate = $false
        }
    }
    else {
        Write-Host "AppRole '$Value': CREATING"
        $appRole = New-Object -TypeName "Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphAppRole" `
                        -Property @{
                            displayName = $DisplayName
                            id = $AppRoleId
                            isEnabled = $Enabled
                            description = $Description
                            value = $Value
                            allowedMemberType = $AllowedMemberTypes
                        }
        $app.AppRole += @($appRole)
    }

    if ($doUpdate) {
        Update-AzADApplication -ObjectId $AppObjectId -AppRole $app.AppRole

        $app = Get-AzADApplication -Id $AppObjectId    
    }

    return $app
}
