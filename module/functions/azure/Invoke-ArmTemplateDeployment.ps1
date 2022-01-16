# <copyright file="Invoke-ArmTemplateDeployment.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Uses PowerShell Az to perform an ARM template deployment, staging any linked templates as required.

.DESCRIPTION
Stages the shared ARM templates included in this module and any additional templates specified by the caller to an Azure storage account, before
creating the target resource group (if necessary) and invoking the deployment of the main template (which is not staged).

Also provides support for retries for any errors not caused by 'InvalidTemplate' exceptions.

.PARAMETER DeploymentScope
The target scope of the ARM deployment (e.g. Resource Group, Subscription, Tenant)

.PARAMETER ResourceGroupName
The name of the target resource group.

.PARAMETER Location
The Azure location of the target resource group.

.PARAMETER ArmTemplatePath
The file system path to the main ARM template to be deployed.

.PARAMETER TemplateParameters
Hashtable containing the values for the parameters required by the ARM template.

.PARAMETER NoArtifacts
When specified, skips the staging of any ARM artifacts to an Azure storage account.

.PARAMETER AdditionalArtifactsFolderPath
The file system path to additional linked ARM templates that need to be staged. The path should be to a directory that contains a
directory named 'templates', within which these templates should reside.

.PARAMETER SharedArtifactsFolderPath
The file system path to the set of shared linked ARM templates that need to be staged. If using the library of such templates contained
within this module, then this need not be specified.

.PARAMETER StagingStorageAccountName
The Azure storage account to use for staging ARM artifacts. When not specified, a name will be generated based on the Azure location and
subscription ID. (e.g. 'stageeastus1234567890123)

.PARAMETER StorageResourceGroupName
The resource group where the Azure storage account used for staging ARM artifacts resides. When not specified, a name will be derived based on
the Azure location.

.PARAMETER ArtifactsLocationName
The name of the parameter used by the main ARM template to refer to the location of the staged ARM artifacts.

.PARAMETER ArtifactsLocationSasTokenName
The name of the parameter used by the main ARM template to refer to the SAS token that has access to the Azure storage account used for staging
ARM artifacts.

.OUTPUTS
Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroupDeployment
#>
function Invoke-ArmTemplateDeployment
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $Location,

        [Parameter(Mandatory=$true)]
        [string] $ArmTemplatePath,

        [ValidateSet("ResourceGroup","Subscription","ManagementGroup","Tenant")]
        [string] $DeploymentScope = "ResourceGroup",

        [string] $ResourceGroupName,

        [Hashtable] $TemplateParameters = @{},
        [switch] $NoArtifacts,
        [string] $AdditionalArtifactsFolderPath,
        [string] $SharedArtifactsFolderPath = (Join-Path $PSScriptRoot '../../arm-artifacts' -Resolve),
        [string] $StagingStorageAccountName,
        [string] $StorageResourceGroupName = "arm-deploy-staging-$Location",
        [string] $ArtifactsLocationName = '_artifactsLocation',
        [string] $ArtifactsLocationSasTokenName = '_artifactsLocationSasToken',
        [string] $BicepVersion = "0.4.1124",
        [int] $MaxRetries = 3
    )

    $OptionalParameters = @{}

    # Check whether we have a valid AzPowerShell connection
    _EnsureAzureConnection -AzPowerShell -ErrorAction Stop | Out-Null

    if ($ArmTemplatePath.ToLower().EndsWith(".bicep")) {
        _ensureBicepCliVersionInPath
    }

    # For single ARM template scenarios, ignore the staging functionality
    if (!$NoArtifacts) {
        _DeployArmArtifacts -AdditionalArtifactsFolderPath $AdditionalArtifactsFolderPath `
                            -SharedArtifactsFolderPath $SharedArtifactsFolderPath `
                            -StagingStorageAccountName $StagingStorageAccountName `
                            -StorageResourceGroupName $StorageResourceGroupName `
                            -ArtifactsLocationName $ArtifactsLocationName `
                            -ArtifactsLocationSasTokenName $ArtifactsLocationSasTokenName
    }

    # Create the resource group only when it doesn't already exist
    if ( $DeploymentScope -eq "ResourceGroup" -and `
            $null -eq (Get-AzResourceGroup -Name $ResourceGroupName -Verbose -ErrorAction SilentlyContinue) ) {
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Verbose -Force -ErrorAction Stop | Out-Null
    }

    # Setup required parameters for the relevant deployment type
    $argsForDeployType = @{ TemplateFile = $ArmTemplatePath }
    if ($DeploymentScope -eq "ResourceGroup") {
        $argsForDeployType += @{ ResourceGroupName = $ResourceGroupName }
    }
    else {
        $argsForDeployType += @{ Location = $Location }
    }

    Write-Host "Validating ARM template ($ArmTemplatePath)..."
    # Dynamically call the relevant cmdlet for the current deployment type
    $validationErrors = & "Test-Az$($DeploymentScope)Deployment" `
                                    @argsForDeployType `
                                    @OptionalParameters `
                                    @TemplateParameters `
                                    -Verbose
    if ($validationErrors) {
        Write-Warning ($validationErrors | Out-String)
        throw "ARM Template validation errors - check previous warnings"
    }

    # Deploy the ARM template with a built-in retry loop to try and limit the disruption from spurious ARM errors
    $retries = 1
    $DeploymentResult = $null
    $success = $false

    # DeploymentScope specific args for the actual deployment
    if ($DeploymentScope -eq "ResourceGroup") {
        $argsForDeployType += @{ Force = $True }
    }

    while (!$success -and $retries -le $MaxRetries) {
        if ($retries -gt 1) { Write-Host "Waiting 30secs before retry..."; Start-Sleep -Seconds 30 }

        # $ErrorMessages = $null
        $deployName = "{0}-{1}-{2}" -f (Get-ChildItem $ArmTemplatePath).BaseName, `
                                        ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm'), `
                                        $retries
        try {
            Write-Host "Deploying ARM template ($ArmTemplatePath)..."
            # Dynamically call the relevant cmdlet for the current deployment type
            $DeploymentResult = & "New-Az$($DeploymentScope)Deployment" `
                                        -Name $deployName `
                                        @argsForDeployType `
                                        @OptionalParameters `
                                        @TemplateParameters `
                                        -Verbose `
                                        -WhatIf:$WhatIfPreference

            # The template deployed successfully, drop out of retry loop
            $success = $true
            Write-Host "ARM template deployment successful"
        }
        catch {
            # Catch any exceptions that indicate a template issue
            if ($_.Exception.Message -match "Code=InvalidTemplate" -or 
                    $_.Exception -is [Newtonsoft.Json.JsonReaderException]
                ) {
                Write-Host "Invalid ARM template error detected - skipping retries"
                throw $_
            }
            elseif ($retries -ge $MaxRetries) {
                Write-Host "Unable to deploy ARM template - retry attempts exceeded"
                throw $_
            }
            Write-Host ("Attempt {0}/{1} failed: {2}" -f $retries, $MaxRetries, $_.Exception.Message)
            $retries++
        }
    }

    return $DeploymentResult
}

function _ensureBicepCliVersionInPath
{
    Write-Verbose "Required Bicep version is v$BicepVersion"
    # Az.PowerShell expects to find the Bicep CLI via the PATH environment variable
    $existingBicepCommand = Get-Command bicep -ErrorAction SilentlyContinue
    if ($existingBicepCommand) {
        # Check the version currently installed
        $existingBicepCommandVersion = "{0}.{1}.{2}" -f $existingBicepCommand.Version.Major,
                                                        $existingBicepCommand.Version.Minor,
                                                        $existingBicepCommand.Version.Build
        Write-Verbose "Existing installation of Bicep is v$existingBicepCommandVersion"
    }
    
    if ($existingBicepCommandVersion -ne $BicepVersion) {
        # If the installed version is not what we need, then we:
        #   1) fallback to using the mechanism in the Azure CLI to install Bicep
        #   2) insert that path to the front the PATH environment variable, so it is used ahead of any existing version

        # Check whether Azure CLI has prevoiusly installed the required version
        $existingAzCliBicepVersion = "$(az bicep version)"
        Write-Verbose "az bicep version: $existingAzCliBicepVersion"
        if ($existingAzCliBicepVersion.IndexOf("Bicep CLI version $BicepVersion") -lt 0) {
            Write-Verbose "Installing Bicep CLI tool via Azure CLI"
            & az bicep install --version "v$BicepVersion" | Out-String | Write-Verbose
            & az bicep version | Out-String | Write-Verbose
        }

        # Update the PATH to ensure the Azure CLI copy of Bicep CLI is used by Az.PowerShell
        $bicepPath = [IO.Path]::Join($env:HOME, ".azure", "bin")
        $env:PATH = "$bicepPath{0}$($env:PATH){0}" -f [IO.Path]::PathSeparator
        # verify the install
        Get-Command bicep | Select-Object -ExpandProperty Path | Out-String | Write-Verbose
    }
}