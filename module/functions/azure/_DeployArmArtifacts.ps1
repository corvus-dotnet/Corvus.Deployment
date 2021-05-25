# <copyright file="_DeployArmArtifacts.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Handles uploading linked ARM templates and other artifacts to a staging storage account.

.DESCRIPTION
Handles uploading linked ARM templates and other artifacts to a staging storage account.

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

#>
function _DeployArmArtifacts
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $SharedArtifactsFolderPath,

        [Parameter(Mandatory=$true)]
        [string] $StorageResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string] $ArtifactsLocationName,

        [Parameter(Mandatory=$true)]
        [string] $ArtifactsLocationSasTokenName,

        [string] $AdditionalArtifactsFolderPath,
        [string] $StagingStorageAccountName

    )

    # Check whether we have a valid AzPowerShell connection
    _EnsureAzureConnection -AzPowerShell -ErrorAction Stop | Out-Null

    if (!$StagingStorageAccountName) {
        $StagingStorageAccountName = ('stage{0}{1}' -f $Location, ($script:moduleContext.SubscriptionId.ToString()).Replace('-', '').ToLowerInvariant()).SubString(0, 24)
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