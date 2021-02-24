function _applyAzureAdApiPermission {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $apiId,

        [Parameter(Mandatory = $true)]
        [string] $apiPermissionId,

        [Parameter(Mandatory = $true)]
        [string] $appId,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $existingPermissions
    )

    if ( !$existingApiPermissions -or `
            ([array]($existingApiPermissions.resourceAccess.id) -inotcontains $apiPermissionId)
    ) {
        $permArgs = @(
            "ad app permission add"
            "--api {0}" -f $apiId
            "--api-permissions {0}=Role" -f $apiPermissionId
            "--id {0}" -f $appId
        )
        Write-Host ("Granting API permission: {0}" -f $apiPermissionId)
        Invoke-AzCli $permArgs
        Write-Host "Complete"
        return $true
    }
    else {
        Write-Host ("API permission '{0}' already assigned - skipping" -f $apiPermissionId)
        return $false
    }
}
