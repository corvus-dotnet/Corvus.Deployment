# <copyright file="Assert-AzureAdSecurityGroup.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Creates or updates a AzureAD group.

.DESCRIPTION
Uses Azure PowerShell to create an AzureAD security group.  This function assumes that the caller will not have full AzureAD
permissions (i.e. 'Group.Create' instead of 'Group.ReadWrite.All') as this is typically the case for least-privilege
automation scenarios.  It therefore assumes that group owners can only be configured as part of the creation request, as this
is supported for callers with 'Group.Create' permissions.

.PARAMETER Name
The display name of the group.

.PARAMETER EmailName
The username portion of the email address associated with the group

.PARAMETER Description
The description of the group

.PARAMETER OwnersToAssignOnCreation
The DisplayName, UserPrincipalName, ObjectId or ApplicationId of the users, groups, service principals to assign as owners to the group.
Note, that if the group already exists, we will not attempt to assign the owners (see the note in the description for me details)

.PARAMETER StrictMode
When true, the group's description forms part of the idempotency check.  If the specified description does not match the group's
definition in AzureAD, then it will be updated to ensure it matches.

.OUTPUTS
AzureAD group definition object

#>
function Assert-AzureAdSecurityGroup
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $EmailName,

        [Parameter()]
        [string] $Description,

        [Parameter()]
        [string[]] $OwnersToAssignOnCreation,

        [Parameter()]
        [bool] $StrictMode = $true      # default to true, to ensure backwards-compatible behaviour
    )

    # Check whether we have a valid AzPowerShell connection, but no subscription-level access is required
    _EnsureAzureConnection -AzPowerShell -TenantOnly -ErrorAction Stop | Out-Null
    
    $existingGroup = Get-AzADGroup -DisplayName $name

    # Resolve the ObjectId for any specified owners
    $ownersToAssignObjectIds = $OwnersToAssignOnCreation |
        ForEach-Object { Get-AzureAdDirectoryObject -Criterion $_ }

    if ($existingGroup) {
        Write-Host "Security group with name $($existingGroup.displayName) already exists."

        if ($ownersToAssignObjectIds -and $StrictMode) {
            $existingOwners = _getGroupOwners -GroupObjectId $existingGroup.id

            $ownersToAssignObjectIds | ForEach-Object {
                if ($_ -notin $existingOwners) {
                    Write-Warning "Object ID '$_' was specified to be assigned as group owner, but group already exists and the ownership cannot be updated."
                }
            }
        }

        $requestParams = _buildUpdateRequest
        if ($requestParams) {
            Write-Host "Security group needs to be updated..."
        }
    }
    else {
        Write-Host "Security group with name $Name doesn't exist. Creating..."
        $requestParams = _buildCreateRequest -OwnersObjectIds $ownersToAssignObjectIds
    }

    $result = $null
    if ($requestParams) {
        $result = Invoke-AzRestMethod @requestParams
        Write-Host "AAD Security group processing complete"
    }

    return $result
}

function _buildUpdateRequest {
    if ($StrictMode -and $Description -ine $existingGroup.description -and ![string]::IsNullOrEmpty($Description)) {
        Write-Host "Description field has changed. Updating..."

        $updateBody = @{
            displayName = $existingGroup.displayName
            mailNickname = $existingGroup.mailNickname
            mailEnabled = $existingGroup.mailEnabled
            securityEnabled = $existingGroup.securityEnabled
            description = $Description                
        }
    
        $restParams = @{
            Uri = "https://graph.microsoft.com/v1.0/groups/$($existingGroup.Id)"
            Method = "POST"
            Payload = ($updateBody | ConvertTo-Json -Depth 3 -Compress)
        }

        return $restParams
    }
    else {
        return $null
    }
}

function _buildCreateRequest {
    param (
        [string[]] $OwnersObjectIds
    )

    $body = @{
        displayName = $Name
        mailNickname = $EmailName
        mailEnabled = $false
        securityEnabled = $true
    }

    if ($OwnersToAssignOnCreation) {
        $body["owners@odata.bind"] = @()
        $body["owners@odata.bind"] += $OwnersObjectIds | ForEach-Object {
            "https://graph.microsoft.com/v1.0/directoryObjects/$_"
        }
    }

    if ($Description) {
        $body["description"] = $Description
    }

    $restParams = @{
        Uri = "https://graph.microsoft.com/v1.0/groups"
        Method = "POST"
        Payload = ($body | ConvertTo-Json -Depth 3 -Compress)
    }

    return $restParams
}

function _getGroupOwners {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $GroupObjectId
    )

    Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/groups/$GroupObjectId/owners" |
            Select-Object -ExpandProperty Content |
            ConvertFrom-Json |
            Select-Object -ExpandProperty value |
            Select-Object -ExpandProperty id
}