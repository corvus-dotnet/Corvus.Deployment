# Temporary Network Access Rule Handlers

The [`Set-TemporaryAzureResourceNetworkAccess`](../Set-TemporaryAzureResourceNetworkAccess.ps1) function streamlines the process of configuring network access rules that are sometimes briefly required during the execution of a CI/CD pipeline that needs to interact with Azure resources with restricted access from the public Internet.

The precise steps required for this functionality is specific Azure resource.  For this reason a pluggable 'handler' approach has been implemented so that the range of supported Azure resources can be more easily extended.

This directory contains those 'handler' implementations.

When writing a new handler, you must consider the following requirements:

* Filename must begin with a `_` prefix, to ensure the function are private to the module (i.e. not exported)
* Remainder of the filename must match how the resource type will be referenced via the `ResourceType` parameter of `Set-TemporaryAzureResourceNetworkAccess` (e.g. `_MyNewResourceType.ps1`)
* Each handler script must implement the following 2 [advanced functions](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced):
    * `_addTempRule_<handler-name>`
        * This must be able to update the specified resource to grant network access to a specified IP address (see below)
    * `_removeExistingTempRules_<handler-name>`
        * This must be able to find and remove/revert any changes made by the above function
    * `_waitForRule_<handler-name>`
        * This implements waiting for an update to take effect, typically a simple delay, based on the target resource type
* The above functions must accept the following string parameters:
    * `ResourceGroupName`
    * `ResourceName`
* The following script-level variables will be available to the handler functions:
    * `$script:currentPublicIpAddress` - the public IP address of the system running the function
    * `$script:ruleName` - the name to assign to the rule (where supported) and to use when searching for temporary rules to remove
    * `$script:ruleDescription` - the description to assign to the rule, where support 

For further details, please refer to the existing handler implementations and their associated integration tests:

* [Azure App Service](./WebApp.ps1) (main web site)
* [Azure App Service](./WebAppScm.ps1) (SCM site)
* [Azure SQL](./SqlServer.ps1)
* [Azure Storage](./StorageAccount.ps1)
* [Integration Test Suite](../Set-TemporaryAzureResourceNetworkAccess.Tests.ps1)

***NOTE**: Currently, the test suite is centralised as this reduces the time associated with Azure resource setup and clear-down.*
