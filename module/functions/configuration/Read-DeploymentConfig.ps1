# <copyright file="Read-DeploymentConfig.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Reads the deployment configuration from a convention-based directory structure.

.DESCRIPTION
Reads the deployment configuration from a convention-based directory structure and applies validation for any
configuration settings that have been flagged as 'required'.

.PARAMETER ConfigPath
The full path to the root of the deployment configuration repository.

.PARAMETER EnvironmentConfigName
The name of the file in the deployment configuration repository that contains the configuration settings for
the target environment.

.PARAMETER SharedConfigName
The name of the file in the deployment configuration repository that contains the configuration settings that
are shared by all environments.

.PARAMETER ConfigFileExtension
The file extension used by files within the deployment configuration repository.

.PARAMETER RequiredConfigurationKey
The configuration setting that contains the list of any other required configuration settings.  This is used to
pre-validate that the loaded deployment configuration has all the required values.

.NOTES
Configuration values can be literal values or can reference configuration handlers that are responsible for
resolving the value.  For example, the following syntax can be used to have a configuration value populated
from an Azure Key Vault Secret:

$myPassword = "@Microsoft.KeyVault(SecretUri=https://myvault.vault.azure.net/secrets/my-password)"

.OUTPUTS
Hashtable

#>
function Read-DeploymentConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $ConfigPath,

        [Parameter(Mandatory=$true)]
        [string] $EnvironmentConfigName,

        [string] $SharedConfigName = "common",
        [string] $ConfigFileExtension = ".ps1",
        [string] $RequiredConfigurationKey = 'RequiredConfiguration'
    )

    $sharedConfigFile = Join-Path $ConfigPath "$($SharedConfigName)$($ConfigFileExtension)" -Resolve
    $environmentConfigFile = Join-Path $ConfigPath "$($EnvironmentConfigName)$($ConfigFileExtension)" -Resolve

    # execute the config repo files to evaluate the configuration and merge the results
    $deploymentConfig = (_DotSourceScriptFile -Path $sharedConfigFile) | `
                            Merge-Hashtables (_DotSourceScriptFile -Path $environmentConfigFile)
    Write-Verbose ($deploymentConfig | Format-Table | Out-String)

    if ( !($deploymentConfig.ContainsKey($RequiredConfigurationKey)) ) {
        Write-Warning "Required configuration settings have not been specified"
        Write-Warning ("Consider setting the '{0}' configuation value with the list of required configuration values" -f $RequiredConfigurationKey)
    }
    else {
        # validate configuration
        Write-Host "Processing configuration for environment '$EnvironmentConfigName'" -f Green
        $configOk = $true
        foreach ($requiredSetting in $deploymentConfig[$RequiredConfigurationKey]) {
            if ( !($deploymentConfig.ContainsKey($requiredSetting)) -or [string]::IsNullOrEmpty($deploymentConfig[$requiredSetting]) ) {
                $configOk = $false
                Write-Warning "The required configuration setting '$requiredSetting' has not been defined"
            }
        }

        if (!$configOk) {
            Write-Error "The configuration for environment '$EnvironmentConfigName' has failed pre-validation - check above warnings"
        }
    }

    $resolvedDeploymentConfig = _ResolveDeploymentConfigValues $deploymentConfig

    $resolvedDeploymentConfig
}