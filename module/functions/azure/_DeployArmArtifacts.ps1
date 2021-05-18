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