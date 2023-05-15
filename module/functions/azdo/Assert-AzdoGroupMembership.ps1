# <copyright file="Assert-AzdoGroupMembership.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that an Azure DevOps project group has the specified members.

.DESCRIPTION
Synchronises the membership of an existing Azure DevOps project group to match those provided in the
members configuration parameter.

.PARAMETER Name
The name of the group to process.

.PARAMETER Project
The name of the Azure DevOps project.

.PARAMETER Organisation
The name of the Azure DevOps organisation.

.PARAMETER RequiredMembers
An array of hashtables, each representing a required member of the specified group.
@(
    @{
        name = "<member-name>"
        type = "<member-type>"   # valid values are 'user' or 'group'
    }
    ...
)

#>
function Assert-AzdoGroupMembership
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()]
        [string] $Name,

        [Parameter()]
        [string] $Project,

        [Parameter()]
        [Alias("Organization")]
        [string] $Organisation,

        [Parameter()]
        [hashtable[]] $RequiredMembers
    )

    $output = @{
        Added = @()
        Flagged = @()
        Removed = @()
    }

    $orgUrl = Get-AzdoOrganisationUrl $Organisation
    
    # Lookup the group
    $listGroupArgs = @(
        "devops security group list"
        "--organization $orgUrl"
        "--project `"$Project`""
        "--query `"graphGroups[?displayName == '$Name']`""
    )
    $existingGroup = Invoke-AzCli -Command $listGroupArgs -AsJson

    if ($existingGroup) {
        # Lookup the current group members
        $getMemberArgs = @(
            "devops security group membership list"
            "--organization $orgUrl"
            "--id $($existingGroup.descriptor)"
        )
        $existingMembers = Invoke-AzCli -Command $getMemberArgs -AsJson
  
        # add missing members
        foreach ($member in $RequiredMembers) {
            $alreadyMember = _IsAzdoGroupMember -ExistingGroupMembers $existingMembers `
                                                -NewMemberEntry $member
            if (!$alreadyMember) {
                if ( !(_AddGroupMember -WhatIf:$WhatIfPreference) ) {
                    # When _AddGroupMember fails, stop processing this iteration and continue to the next member
                    continue
                }
                $output.Added += $member
            }
            else {
                Write-Verbose "Already a member: $($member.name) [$($member.type)]"
            }
        }

        
        # Audit existing group members who are not in the configuration file
        
        # Project the existing group members into a structure that 
        # we can easily compare with the set of required members
        $existingMembersProjection = $existingMembers.Keys | ForEach-Object {
            $memberId = $existingMembers[$_].descriptor
            # The field used for the comparison is different depending on whether we're considering a user or group
            $memberType = $existingMembers[$_].subjectKind
            $memberName = $memberType -eq 'group' ? $existingMembers[$_].displayName : $existingMembers[$_].principalName
            @{ id = $memberId; name = $memberName; type = $memberType }
        }

        # Log a warning for unexpected group members
        $extraMembers = $existingMembersProjection | Where-Object { 
            $_.name -notin ([array]($RequiredMembers | Select-Object -ExpandProperty name))
        }
        foreach ($extraMember in $extraMembers) {
            Write-Warning ("[UNEXPECTED-USER] {0} '{1}' is a member of '{2}'" -f $extraMember.type, $extraMember.name, $Name)
            $output.Flagged += $extraMember
        }
    }

    return $output
}