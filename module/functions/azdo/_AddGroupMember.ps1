# <copyright file="_AddGroupMember.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Adds a member to an Azure DevOps project group.

.DESCRIPTION
Adds a member to an Azure DevOps project group.

#>
function _AddGroupMember
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Verbose "Adding member: $($member.name) [$($member.type)]"
    switch ($member.type) {
        "user" {
            $addUserArgs = @(
                "devops security group membership add"
                "--organization $orgUrl"
                "--group-id `"$($existingGroup.descriptor)`""
                "--member-id `"$($member.name)`""
            )
            if ($PSCmdlet.ShouldProcess($Name)) {
                Invoke-CorvusAzCli -Command $addUserArgs
            }
            else {
                Write-Host "[DRYRUN] Add member: $($member.name) [$($member.type)]" -f Magenta
            }
        }
        "group" {
            $groupListArgs = @(
                "ad group list"
                "--display-name `"$($member.name)`""
                "--query `"[?displayName == '$($member.name)' && securityEnabled]`""
            )
            $aadObject = Invoke-CorvusAzCli -Command $groupListArgs -AsJson
            
            if ($aadObject) {
                # Register the AzureAD group with Azure DevOps and add it as a member
                $groupCreateArgs = @(
                    "devops security group create"
                    "--organization $orgUrl"
                    "--origin-id $($aadObject.objectId)"
                    "--groups `"$($existingGroup.descriptor)`""
                    "--scope organization"
                )
                if ($PSCmdlet.ShouldProcess($Name)) {
                    Invoke-CorvusAzCli -Command $groupCreateArgs
                }
                else {
                    Write-Host "[DRYRUN] Add member: $($member.name) [$($member.type)]" -f Magenta
                }
                return $true
            }
            else {
                Write-Warning "The referenced group '$($member.name)' could not be found in Azure Active Directory - skipping"
                return $false
            }                                                    
        }
    }
}