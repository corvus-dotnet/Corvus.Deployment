# <copyright file="Invoke-MarainServiceDeployment.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Performs the provisioning and deployment of an Azure web app designed to use the Marain services.

.DESCRIPTION
Verifies that the Azure Web App is available and then publishes the locally-available .ZIP file to it.

.PARAMETER ResourceGroupLocation
The Azure location of the target resource group.

.PARAMETER AppName
The name of the AzureAD application that represents this service for authentication purposes.

.PARAMETER Prefix
A short string used as a prefix for the naming covention used by the related ARM templates to help ensure uniqueness of
Azure resources across different organisations. (e.g. acme)

.PARAMETER EnvironmentSuffix
A short string representing the lifecycle instance of this service (e.g. dev, test, prod) that forms part of the naming
convention used by the related ARM templates.

.PARAMETER AppInsightsInstrumentationKey
The Azure AppInsights intrumentation key the service will use to access AppInsights.

.PARAMETER ArmTemplatePath
The file system path to the main ARM template to be deployed.

.PARAMETER ApplicationZipPath
The file system path to a .ZIP file containing an Azure web app that is ready to be published.

.PARAMETER ProvisionOnly
When specified, the Azure infrastructure will be provisioned but the application itself will not be deployed.

.PARAMETER RequiresAuthentication
When True, the necessary pre-reqs to allow the service to perform authentication will be setup.

.PARAMETER TenancyServiceUri
The URI of the Marain Tenancy service to which this service will be registered.

.PARAMETER TennancyServiceAppId
The AzureAD ApplicationId of the Marain Tenancy service to which this service will require access.

.PARAMETER ResourceGroupName
The name of the target resource group.

.PARAMETER AdditionalArmTemplateParameters
Hashtable containing the values for any additional parameters required by the main ARM template. The following parameters are
handled automatically:

    appName
    environmentSuffix
    marainPrefix
    appInsightsInstrumentationKey
    tenancyServiceBaseUri
    tenancyServiceResourceIdForMsiAuthentication

.PARAMETER AdditionalArmArtifactsFolder
The file system path to any additional linked ARM templates used by the main ARM template, that will need to be staged.

The path should be to a directory that contains another directory named 'templates', within which these templates should reside.

.PARAMETER DeployAppOnly
When specified, the required Azure infrastructure is assumed to be in-place and only the application will be deployed.

.OUTPUTS
None
#>
function Invoke-MarainServiceDeployment
{
    [CmdletBinding()]
    param
    (
        # Mandatory parameters
        [Parameter(Mandatory=$true, ParameterSetName = "provision")]
        [string] $ResourceGroupLocation,
        
        [Parameter(Mandatory=$true, ParameterSetName = "provision")]
        [Parameter(ParameterSetName = "deploy")]
        [string] $AppName,

        [Parameter(Mandatory=$true, ParameterSetName = "provision")]
        [Parameter(ParameterSetName = "deploy")]
        [string] $Prefix,

        [Parameter(Mandatory=$true, ParameterSetName = "provision")]
        [Parameter(ParameterSetName = "deploy")]
        [string] $EnvironmentSuffix,
        
        [Parameter(Mandatory=$true, ParameterSetName = "provision")]
        [string] $AppInsightsInstrumentationKey,
                             
        [Parameter(Mandatory=$true, ParameterSetName = "provision")]
        [string] $ArmTemplatePath,

        [Parameter(Mandatory=$true, ParameterSetName = "deploy")]
        [Parameter(ParameterSetName = "provision")]
        [string] $ApplicationZipPath,

        
        # optional 'provision-only' parameters
        [Parameter(ParameterSetName = "provision")]
        [switch] $ProvisionOnly,

        [Parameter(ParameterSetName = "provision")]
        [switch] $RequiresAuthentication,

        [Parameter(ParameterSetName = "provision")]
        [uri] $TenancyServiceUri = "https://$($Prefix)$($EnvironmentSuffix)tenancy.azurewebsites.net",

        [Parameter(ParameterSetName = "provision")]
        [guid] $TenancyServiceAppId,
        
        [Parameter(ParameterSetName = "provision")]
        [string] $ResourceGroupName = "$Prefix-rg-$AppName-$EnvironmentSuffix",     # TODO: tool-based naming conventions
        
        [Parameter(ParameterSetName = "provision")]
        [hashtable] $AdditionalArmTemplateParameters,
        
        [Parameter(ParameterSetName = "provision")]
        [string] $AdditionalArmArtifactsFolder,
        

        # optional 'deploy' parameters
        [Parameter(ParameterSetName = "deploy")]
        [switch] $DeployAppOnly
    )

    # Provisioning steps
    if (!$DeployAppOnly) {

        # Handle lookup for Tenancy Service AppId, if not provided
        if ($null -eq $TenancyServiceAppId) {
            $tenancyAppRegistration = "{0}{1}tenancy" -f $Prefix, $EnvironmentSuffix     # TODO: tool-based naming conventions
            Write-Host "Lookup Tenancy service appId - $tenancyAppRegistration"
            $tenancyAppRegistration = Get-AzADApplication -DisplayName $tenancyAppRegistration
            [guid]$TenancyServiceAppId = $tenancyAppRegistration.ApplicationId
            Write-Host "Found Tenancy service appId: $($TenancyServiceAppId.Guid)"
        }

        # standard parameters for all variants of marain services
        $templateParameters = @{
            appName = $AppName
            environmentSuffix = $EnvironmentSuffix
            marainPrefix = $Prefix
            appInsightsInstrumentationKey = $AppInsightsInstrumentationKey
            tenancyServiceBaseUri = $TenancyServiceUri.AbsoluteUri
            tenancyServiceResourceIdForMsiAuthentication = $TenancyServiceAppId.Guid
        }

        $appRegistrationName = "{0}{1}{2}" -f $Prefix, $EnvironmentSuffix, $AppName     # TODO: tool-based naming conventions
        if ($RequiresAuthentication) {
            # Register azureAD app
            Write-Host "The Marain service '$appRegistrationName' requires authentication - ensuring AzureAD app registration"
            $appRegistration = Assert-AzureAdAppForAppService -AppName $appRegistrationName

            # TODO: add any ARM template parameters required by this variant
        }

        $results = Invoke-ArmTemplateDeployment -ResourceGroupName $ResourceGroupName `
                                                -Location $ResourceGroupLocation `
                                                -ArmTemplatePath $ArmTemplatePath `
                                                -TemplateParameters ($templateParameters + $AdditionalArmTemplateParameters) `
                                                -AdditionalArtifactsFolderPath $AdditionalArmArtifactsFolder

        Write-Host ("Function app MSI: {0}" -f $results.Outputs.functionServicePrincipalId.Value)
    }

    # App deployment steps
    if (!$ProvisionOnly) {
        if ( !(Test-Path $ApplicationZipPath) ) {
            Write-Error "Could not find application package: $ApplicationZipPath"
        }

        $appServiceName = "{0}{1}{2}" -f $Prefix, $EnvironmentSuffix, $AppName      # TODO: tool-based naming conventions
        $publishResults = Publish-AppServiceFromZipFile -Path (Resolve-Path $ApplicationZipPath).Path -AppServiceName $appServiceName
    }
}