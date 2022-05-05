# <copyright file="Assert-AzureAdGroupMembership.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Configures the membership of an AzureAD group.

.DESCRIPTION
Uses Azure PowerShell to manage AzureAD group membership.

.PARAMETER Name
The display name of the group.

.PARAMETER ObjectId
The objectId of the group.

.PARAMETER Members
The list of AzureAD objects that should be members of the group. These can be specified using
'DisplayName', 'ObjectId', 'ApplicationId' or 'UserPrincipalName'.

.PARAMETER StrictMode
When true, existing group members not specified in the 'RequiredMembers' parameters will be removed from the group.

.OUTPUTS
AzureAD group definition object

.EXAMPLE

Assert-AzureAdGroupMembership -Name "MyGroup" -RequiredMembers @("MyOtherGroup", "MyUser", "MyServicePrincipal")
Assert-AzureAdGroupMembership -Name "MyGroup" -RequiredMembers @("MyOtherGroup", "MyUser@nowhere.org", "be2a6313-cb3a-45ad-a70f-cbac2a8c565f")
Assert-AzureAdGroupMembership -Name "MyGroup" -RequiredMembers @("f7f0545c-82b5-4008-bebf-f73fb1d5a7f8", "MyUser@nowhere.org", "be2a6313-cb3a-45ad-a70f-cbac2a8c565f")

#>
function Assert-AzureAdGroupMembership
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ParameterSetName="ByName")]
        [string] $Name,

        [Parameter(Mandatory=$true, ParameterSetName="ByObjectId")]
        [string] $ObjectId,

        [Parameter()]
        [string[]] $RequiredMembers,

        [Parameter()]
        [ValidateSet("Security","Distribution")]
        [string] $GroupType = "Security",

        [Parameter()]
        [bool] $StrictMode
    )

    # Check whether we have a valid AzPowerShell connection, but no subscription-level access is required
    _EnsureAzureConnection -AzPowerShell -TenantOnly -ErrorAction Stop | Out-Null

    # Setup the parameters for 'Get-AzADGroup' based on whether we've been given a group Name or ObjectId
    $groupLookupSplat = $PSCmdlet.ParameterSetName -eq "ByName" ? @{DisplayName = $Name} : @{ObjectId = $ObjectId}
    [array]$groups = Get-AzADGroup @groupLookupSplat | `
        Where-Object { $_.SecurityEnabled -eq ($GroupType -eq "Security") }

    if (!$groups) {
        throw "The specified group could not be found: $($groupLookupSplat.Keys[0])=$($groupLookupSplat.Values[0])"
    }
    elseif ($groups.Count -gt 1) {
        throw "Found multiple matching groups: $($groups | % { "ObjectId=$($_.Id);"} )"
    }
    $group = $groups[0]

    Write-Information "Processing group membership for '$($group.DisplayName)' [ObjectId=$($group.Id)]"

    $existingMemberObjectIds = _getGroupMembers $group.id | Select-Object -ExpandProperty id

    # Required members can be specified in various forms:
    #   - ObjectId (groups, users & service principals)
    #   - DisplayName (groups, users & service principals)
    #   - UserPrincipalName (users only)
    #   - ApplicationId (service principals only)
    #
    # We need the ObjectId to add them to the group - this block handles
    # resolving the above forms into an ObjectId
    $requiredMemberObjectIds = @()
    foreach ($member in $RequiredMembers) {   
        # At this stage we don't know whether the required member is a user, group or service principal.
        # This helper will handle that lookup.
        $resolvedMember = Get-AzureAdDirectoryObject -Criterion $member -Single
        if ($resolvedMember) {
            $requiredMemberObjectIds += $resolvedMember.Id
        }
        else {
            Write-Warning "Skipping '$member' - not found in the directory"
        }
    }
  
    # Add any missing required members
    $membersToAdd = $requiredMemberObjectIds | Where-Object { $_ -notin $existingMemberObjectIds }
    if ($membersToAdd) {
        Write-Information "Adding members: $($membersToAdd -join ', ')"
        $group | Add-AzADGroupMember -MemberObjectId $membersToAdd
    }
    else {
        Write-Information "No members to add"
    }

    # Remove extraneous members, only when StrictMode is enabled
    if ($StrictMode) {
        $membersToRemove = $existingMemberObjectIds | Where-Object { $_ -notin $requiredMemberObjectIds }
        if ($membersToRemove) {
            Write-Information "Removing members: $($membersToRemove -join ', ')"
            $group | Remove-AzADGroupMember -MemberObjectId $membersToRemove
        }
        else {
            Write-Information "No members to remove"
        }
    }

}

function _getGroupMembers {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [guid] $groupObjectId
    )

    # Workaround current limitation in Azure PowerShell whereby 'Get-AzADGroupMember' does not
    # return service principal members
    # ref: https://docs.microsoft.com/en-us/powershell/azure/troubleshooting?view=azps-7.5.0#get-azadgroupmember-doesnt-return-service-principals 
    
    Invoke-AzRestMethod -Uri "https://graph.microsoft.com/beta/groups/$($groupObjectId.Guid)/members" |
        Select-Object -ExpandProperty Content |
        ConvertFrom-Json |
        Select-Object -ExpandProperty value
}
