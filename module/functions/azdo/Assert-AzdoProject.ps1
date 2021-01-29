# <copyright file="Assert-AzdoProject.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that the specfied Azure DevOps project is available.

.DESCRIPTION
Checks the presence of the specfied Azure DevOps project, creating it if necessary.

.PARAMETER Name
The name of the Azure DevOps project.

.PARAMETER Organisation
The name of the Azure DevOps organisation.

.PARAMETER Process
The type of process template to use when creating a project.

.PARAMETER Visibility
The visibility of the project when it is created.

#>
function Assert-AzdoProject
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $Name,

        [Parameter()]
        [string] $Organisation,

        [Parameter()]
        [string] $Process = "basic",

        [Parameter()]
        [string] $Visibility = "private"
    )

    $orgUrl = Get-AdzoOrganisationUrl $Organisation
    
    $existingProjects = az devops project list --organization $orgUrl `
                                                -o json `
                                                --query "value[?name == '$Name']" | ConvertFrom-Json -AsHashtable

    $existingProject = $existingProjects | Where-Object { $_.name -eq $Name }
    
    if (!$existingProject) {
        Write-Host "Creating project '$Name'"
        $existingProject = az devops project create --name $Name `
                                                --process $Process `
                                                --source-control git `
                                                --visibility $Visibility `
                                                --organization $orgUrl `
                                                -o json
    }
    else {
        Write-Verbose "Project '$Name' already exists - skipping"
    }

    return $existingProject
}
