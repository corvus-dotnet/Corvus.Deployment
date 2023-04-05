# <copyright file="Assert-AzureAdServiceAppRoleAssignment.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that an AAD service principal has the specified app role.

.DESCRIPTION
Supports assigning app role (by name) to an AAD service principal.

.PARAMETER AssigneeServicePrincipalObjectId
The ObjectID of the service principal to grant the app role to.

.PARAMETER AppId
The AppID of the application for which the app role applies to.

.PARAMETER AppId
The name of the app role to grant.

#>

function Assert-AzureAdServiceAppRoleAssignment 
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [guid]
        $AssigneeServicePrincipalObjectId,
             
        [Parameter()]
        [guid]
        $AppId,

        [Parameter()]
        [string]
        $AppRoleName
    )

    $application = (az ad sp list --filter "appId eq '$appId'" --query "{ appRoleId: [0] .appRoles [?value=='$AppRoleName'].id | [0], objectId:[0] .id }" -o json) | ConvertFrom-Json

    $assignmentsUri = "https://graph.microsoft.com/v1.0/servicePrincipals/$AssigneeServicePrincipalObjectId/appRoleAssignments"
    $assignedToUri = "https://graph.microsoft.com/v1.0/servicePrincipals/$AssigneeServicePrincipalObjectId/appRoleAssignedTo"

    $appRoleAssignments = (Invoke-CorvusAzCliRestCommand `
        -Uri $assignmentsUri `
        -Method "GET").value

    if ($appRoleAssignments.appRoleId -contains $application.appRoleId) {
        Write-Host "App role '$AppRoleName' assignment already exists for service principal '$AssigneeServicePrincipalObjectId' on application '$AppId'"
    }
    else {
        Write-Host "Assigning app role '$AppRoleName' for service principal '$AssigneeServicePrincipalObjectId' on application '$AppId'"

        Invoke-CorvusAzCliRestCommand `
            -Uri $assignedToUri `
            -Method "POST" `
            -Body @{
                appRoleId = $application.appRoleId
                principalId = $AssigneeServicePrincipalObjectId
                resourceId = $application.objectId
            }
    }
}