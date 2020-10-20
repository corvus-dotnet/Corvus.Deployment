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
        [string] $Description
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
        
            $updateBodyToJson = (ConvertTo-Json $updateBody -Compress).replace('"','\"').replace(':\', ': \')

            $updateCmd = "rest --uri 'https://graph.microsoft.com/v1.0/groups/$($existingGroup.Id)' --method 'PATCH' --body '$updateBodyToJson' --headers content-type=application/json"

            Invoke-AzCli -Command $updateCmd -asJson
        }
    }

    function _createGroup{
        $body = @{
            displayName = $Name
            mailNickname = $EmailName
            mailEnabled = $false
            securityEnabled = $true
        }
    
        if ($Description) {
            $body["description"] = $Description
        }
    
        $bodyToJson = (ConvertTo-Json $body -Compress).replace('"','\"').replace(':\', ': \')
    
        $cmd = "rest --uri 'https://graph.microsoft.com/v1.0/groups' --method 'POST' --body '$bodyToJson' --headers content-type=application/json"
        Invoke-AzCli -Command $cmd -asJson
    }

    $existingGroupCmd = 'rest --uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq {0}" --method "GET"' -f "`'$name`'"

    $existingGroup = (Invoke-AzCli -Command $existingGroupCmd -asJson).value

    if ($existingGroup) {
        Write-Host "Security group with name $($existingGroup.displayName) already exists."

        _updateGroup

        Write-Host "Description field updated."
    }
    else {
        Write-Host "Security group with name $Name doesn't exist. Creating..."

        _createGroup

        Write-Host "AAD Security group created."
    }
}