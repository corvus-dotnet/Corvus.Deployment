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
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()]
        [string] $Name,

        [Parameter()]
        [Alias("Organization")]
        [string] $Organisation,

        [Parameter()]
        [string] $Process = "basic",

        [Parameter()]
        [string] $Visibility = "private"
    )

    $orgUrl = Get-AzdoOrganisationUrl $Organisation
    
    $listProjectArgs = @(
        "devops project list"
        "--organization $orgUrl"
        "--query `"value[?name == '$Name']`""
    )
    $existingProjects = Invoke-CorvusAzCli -Command $listProjectArgs -AsJson

    $existingProject = $existingProjects | Where-Object { $_.name -eq $Name }
    
    if (!$existingProject) {
        Write-Host "Creating project '$Name'"
        $createProjectArgs = @(
            "devops project create"
            "--name `"$Name`""
            "--process $Process"
            "--source-control git"
            "--visibility $Visibility"
            "--organization $orgUrl"
        )
        if ($PSCmdlet.ShouldProcess($Name)) {
            $existingProject = Invoke-CorvusAzCli -Command $createProjectArgs -AsJson
        }
        else {
            Write-Host "[DRYRUN] Create project: $Name" -f Magenta
        }
    }
    else {
        Write-Verbose "Project '$Name' already exists - skipping"
    }

    return $existingProject
}
