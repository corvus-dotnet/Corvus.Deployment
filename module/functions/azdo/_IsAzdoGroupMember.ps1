# <copyright file="_IsAzdoGroupMember.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Returns whether the given identity is already a member of an Azure DevOps project group.

.DESCRIPTION
Returns whether the given identity is already a member of an Azure DevOps project group.

.PARAMETER ExistingGroupMembers
The existing membership of an Azure DevOps group as per the output from 'az devops security group membership list'

.PARAMETER NewMemberEntry
A hashtable representing the new member to be added to the group.
@{
    name = "<member-name>"
    type = "<member-type>"   # valid values are 'user' or 'group'
}

#>
function _IsAzdoGroupMember
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [hashtable] $ExistingGroupMembers,

        [Parameter()]
        [hashtable] $NewMemberEntry
    )

    switch ($NewMemberEntry.type) {
        "user" { $fieldName = "principalName" }
        "group" { $fieldName = "displayName" }
        default { throw "Unknown value for 'type' of group member - 'user' or 'group' supported"}
    }

    $membershipEntry = $ExistingGroupMembers.Keys | `
                            Where-Object { $ExistingGroupMembers[$_].$fieldName -eq $NewMemberEntry.name }

    return ($null -ne $membershipEntry)
}