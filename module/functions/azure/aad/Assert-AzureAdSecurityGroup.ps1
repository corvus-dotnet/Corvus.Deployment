# <copyright file="Assert-AzureAdGroup.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Creates or updates a AzureAD group.

.DESCRIPTION
Uses the azure-cli to configure an AzureAD group.

.PARAMETER Name
The display name of the group.

.PARAMETER EmailName
The username portion of the email address associated with the group

.PARAMETER Description
The description of the group

.PARAMETER OwnersToAssignOnCreation
The object IDs of the principals to assign as owners to the group.
Note, that if the group already exists, we will not attempt to assign the owners (as the principal may not have sufficient privileges)

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
        [string[]] $OwnersToAssignOnCreation
    )

    function _updateGroup{
        if ($Description -ine $existingGroup.description -and ![string]::IsNullOrEmpty($Description)) {
            Write-Host "Description field has changed. Updating..."

            $updateBody = @{
                displayName = $existingGroup.displayName
                mailNickname = $existingGroup.mailNickname
                mailEnabled = $existingGroup.mailEnabled
                securityEnabled = $existingGroup.securityEnabled
                description = $Description                
            }
        
            $updateBodyToJson = (ConvertTo-Json $updateBody -Compress).replace('"','\"').replace(':\', ': \').replace("'", "''")

            $updateCmd = "rest --uri 'https://graph.microsoft.com/v1.0/groups/$($existingGroup.Id)' --method 'PATCH' --body '$updateBodyToJson' --headers content-type=application/json"

            Invoke-AzCli -Command $updateCmd -asJson

            Write-Host "Description field updated."

            $existingGroup.description = $Description

            return $existingGroup
        }
        else {
            return $existingGroup
        }
    }

    function _createGroup{
        $body = @{
            displayName = $Name
            mailNickname = $EmailName
            mailEnabled = $false
            securityEnabled = $true
            
        }

        if ($OwnersToAssignOnCreation) {
            $body["owners@odata.bind"] = @()
            $body["owners@odata.bind"] += $OwnersToAssignOnCreation | ForEach-Object {
                "https://graph.microsoft.com/v1.0/directoryObjects/$_"
            }
        }
    
        if ($Description) {
            $body["description"] = $Description
        }
    
        $bodyToJson = (ConvertTo-Json $body -Compress -Depth 99).replace('"','\"').replace(':\', ': \').replace("'", "''")
    
        $cmd = "rest --uri 'https://graph.microsoft.com/v1.0/groups' --method 'POST' --body '$bodyToJson' --headers content-type=application/json"
        
        $response = Invoke-AzCli -Command $cmd -asJson

        return $response
    }

    $existingGroupCmd = 'rest --uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq {0}" --method "GET"' -f "`'$name`'"

    $existingGroup = (Invoke-AzCli -Command $existingGroupCmd -asJson).value[0]

    if ($existingGroup) {
        Write-Host "Security group with name $($existingGroup.displayName) already exists."

        if ($OwnersToAssignOnCreation) {
            $groupOwnersIds = (Invoke-AzCliRestCommand -Uri "https://graph.microsoft.com/beta/groups/$($existingGroup.id)/owners").value | ForEach-Object {
                $_.id
            }

            $OwnersToAssignOnCreation | ForEach-Object {
                if ($_ -notin $groupOwnersIds) {
                    Write-Warning "Object ID '$_' was specified to be assigned as group owner, but group already exists so we cannot do the assignment."
                }
            }
        }

        $result = _updateGroup
    }
    else {
        Write-Host "Security group with name $Name doesn't exist. Creating..."

        $result = _createGroup

        Write-Host "AAD Security group created."
    }

    return $result
}