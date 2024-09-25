# Corvus.Deployment

![build](https://github.com/corvus-dotnet/Corvus.Deployment/workflows/build/badge.svg)
[![GitHub license](https://img.shields.io/badge/License-Apache%202-blue.svg)](https://raw.githubusercontent.com/corvus-dotnet/Corvus.Deployment/main/LICENSE)

This provides a PowerShell module that includes a collection of useful functions for Azure deployment automation, across the following areas:

* Azure CLI
* Azure Resource Manager
* Deployment Configuration Management
* Microsoft Entra ID (formerly Azure Active Directory)


## Getting Started

The module is available via [PowerShell Gallery](https://www.powershellgallery.com/packages/corvus.deployment) and can be installed in the normal way:

```
Install-Module Corvus.Deployment
```

A full list of available commands and their usage is available using the standard PowerShell help system:
```
Get-Command -Module Corvus.Deployment

Get-Help 
```

***NOTE**: Currently, when importing the module, all commands are made available with a [default command prefix](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_module_manifests#defaultcommandprefix) of `Corvus`. For example, the `Invoke-CommandWithRetry` function is used via `Invoke-CorvusCommandWithRetry`.*

## Configuration Tooling

The `Read-DeploymentConfig` function (available via `Read-CorvusDeploymentConfig`) provides tooling to support maintaining deployment configuration in source-controlled files - typically each deployment environment has its own file.  These files are simple PowerShell scripts that define/return a single hashtable.

```
@{
    applicationPort = 443
    dbName = "MyDB"
}
```

By convention a `config` folder is used to store the files read by this function.

```
<project-root>/
└── config/
    ├── common.ps1
    ├── dev.ps1
    └── prod.ps1
```

The `common.ps1` file can be used to define settings that are common to multiple environments, however, such values can also be overridden in an environment-specific file.

Typically, the remaining files in the `config` directory relate to the target environments for the deployment.

### Configuration Handlers

The tooling also supports the following 'handlers' that allow configuration settings to be resolved via other mechanisms, whereby specific values do not need to be hard-coded in the source controlled files.

#### Azure Key Vault Handler

This allows a configuration setting to have its value resolved by querying a Key Vault Secret, which has obvious security benefits when sensitive configuration values are required at deployment time.

To use this handler, the setting uses the [Azure AppService Key Vault Reference](https://learn.microsoft.com/en-us/azure/app-service/app-service-key-vault-references?tabs=azure-cli#source-app-settings-from-key-vault) syntax:

```
@{
    dbConnectionString = "@Microsoft.KeyVault(SecretUri=https://myvault.vault.azure.net/secrets/myDbConnString/)"
}
```

In the event that any of the specified Key Vault Secrets cannot be retrieved, an exception will be thrown.

#### Environment Variable Handler

This allows a configuration setting to have its value resolved via looking-up an environment variable.  This can be useful when a deployment process needs to be used in scenarios where all the potential environments are not known in advance or where the settings are being provided by the deployment orchestrator (e.g. an Azure DevOps Release Pipeline).

To use this handler, the setting uses the following syntax:

```
@{
    dbConnectionString = "@EnvironmentVariable(MY_DB_CONNECTION_STRING)"
}
```

In the event that any of the specified environment variables are not defined, an exception will be thrown.