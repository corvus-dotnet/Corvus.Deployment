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
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string] $Location,

        [Parameter(Mandatory=$true)]
        [string] $ArmTemplatePath,

        [Hashtable] $TemplateParameters = @{},
        [switch] $NoArtifacts,
        [string] $AdditionalArtifactsFolderPath,
        [string] $SharedArtifactsFolderPath = (Join-Path $PSScriptRoot '../../arm-artifacts' -Resolve),
        [string] $StagingStorageAccountName,
        [string] $StorageResourceGroupName = "arm-deploy-staging-$Location",
        [string] $ArtifactsLocationName = '_artifactsLocation',
        [string] $ArtifactsLocationSasTokenName = '_artifactsLocationSasToken'
    )

    $OptionalParameters = @{}

    # For single ARM template scenarios, ignore the staging functionality
    if (!$NoArtifacts) {
        if (!$StagingStorageAccountName) {
            $StagingStorageAccountName = ('stage{0}{1}' -f $Location, ($script:AzContext.Subscription.Id).Replace('-', '').ToLowerInvariant()).SubString(0, 24)
        }
        $StorageContainerName = $ResourceGroupName.ToLowerInvariant().Replace(".", "") + '-stageartifacts'

        # Lookup whether the storage account already exists elsewhere in the current subscription
        $StorageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $StagingStorageAccountName }

        # Create the storage account if it doesn't already exist
        if ($null -eq $StorageAccount) {
            New-AzResourceGroup -Location $Location -Name $StorageResourceGroupName -Force
            $StorageAccount = New-AzStorageAccount -StorageAccountName $StagingStorageAccountName `
                                                -Type 'Standard_LRS' `
                                                -ResourceGroupName $StorageResourceGroupName `
                                                -Location $Location
        }

        # Copy files from the local storage staging location to the storage account container
        New-AzStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1

        # upload shared linked templates
        $sharedArtifactFilePaths = Get-ChildItem $SharedArtifactsFolderPath -Recurse -File | ForEach-Object -Process {$_.FullName}
        foreach ($SourcePath in $sharedArtifactFilePaths) {
            Set-AzStorageBlobContent `
                -File $SourcePath `
                -Blob $SourcePath.Substring($SharedArtifactsFolderPath.length + 1) `
                -Container $StorageContainerName `
                -Context $StorageAccount.Context `
                -Force `
                -Verbose:$false | Out-Null
        }

        # upload any additional linked templates
        if ($AdditionalArtifactsFolderPath) {
            $additionalArtifactFilePaths = Get-ChildItem $AdditionalArtifactsFolderPath -Recurse -File | ForEach-Object -Process {$_.FullName}
            foreach ($SourcePath in $additionalArtifactFilePaths) {
                Set-AzStorageBlobContent `
                    -File $SourcePath `
                    -Blob $SourcePath.Substring($AdditionalArtifactsFolderPath.length + 1) `
                    -Container $StorageContainerName `
                    -Context $StorageAccount.Context `
                    -Force `
                    -Verbose:$false | Out-Null
            }
        }

        $OptionalParameters[$ArtifactsLocationName] = $StorageAccount.Context.BlobEndPoint + $StorageContainerName
        # Generate a 4 hour SAS token for the artifacts location if one was not provided in the parameters file
        $StagingSasToken = New-AzStorageContainerSASToken `
                                    -Name $StorageContainerName `
                                    -Context $StorageAccount.Context `
                                    -Permission r `
                                    -ExpiryTime (Get-Date).AddHours(4)
        $OptionalParameters[$ArtifactsLocationSasTokenName] = ConvertTo-SecureString -AsPlainText -Force $StagingSasToken
    }

    # Create the resource group only when it doesn't already exist
    if ( $null -eq (Get-AzResourceGroup -Name $ResourceGroupName -Verbose -ErrorAction SilentlyContinue) ) {
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Verbose -Force -ErrorAction Stop
    }

    Write-Host "Validating ARM template ($ArmTemplatePath)..."
    $validationErrors = Test-AzResourceGroupDeployment `
                        -ResourceGroupName $ResourceGroupName `
                        -TemplateFile $ArmTemplatePath `
                        @OptionalParameters `
                        @TemplateParameters `
                        -Verbose
    if ($validationErrors) {
        Write-Warning ($validationErrors | Out-String)
        throw "ARM Template validation errors - check previous warnings"
    }

    # Deploy the ARM template with a built-in retry loop to try and limit the disruption from spurious ARM errors
    $retries = 1
    $maxRetries = 3
    $DeploymentResult = $null
    $success = $false
    while (!$success -and $retries -le $maxRetries) {
        if ($retries -gt 1) { Write-Host "Waiting 30secs before retry..."; Start-Sleep -Seconds 30 }

        # $ErrorMessages = $null
        $deployName = "{0}-{1}-{2}" -f (Get-ChildItem $ArmTemplatePath).BaseName, `
                                        ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm'), `
                                        $retries
        try {
            Write-Host "Deploying ARM template ($ArmTemplatePath)..."
            $DeploymentResult = New-AzResourceGroupDeployment `
                -Name $deployName `
                -ResourceGroupName $ResourceGroupName `
                -TemplateFile $ArmTemplatePath `
                @OptionalParameters `
                @TemplateParameters `
                -Force `
                -Verbose

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
            elseif ($retries -ge $maxRetries) {
                Write-Host "Unable to deploy ARM template - retry attempts exceeded"
                throw $_
            }
            Write-Host ("Attempt {0}/{1} failed: {2}" -f $retries, $maxRetries, $_.Exception.Message)
            $retries++
        }
    }

    return $DeploymentResult
}