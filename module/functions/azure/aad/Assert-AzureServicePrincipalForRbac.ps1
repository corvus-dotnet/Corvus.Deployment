# <copyright file="Assert-AzureServicePrincipalForRbac.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that an Azure AD service principal exists, creating if necessary.  Optionally storing the app credential
in Azure Key Vault.

.DESCRIPTION
Ensures that a suitable Azure AD application & service principal exists.  Optionally storing the app credential
in Azure Key Vault.

.PARAMETER Name
The display name of the Azure AD service principal.

.PARAMETER CredentialDisplayName
The label applied to the created/updated credential, which is important for traceability purposes.

.PARAMETER KeyVaultName
The key vault where that client secret will be stored.

.PARAMETER KeyVaultSecretName
The key vault secret name that client secret will be stored in.

.PARAMETER RotateSecret
When specified, the client secret will be regenerated.

.PARAMETER UseApplicationCredential
When specified, the managed credential will be associated with the App registration, otherwise it will be associated
with the Service Principal object.

.OUTPUTS
Returns a tuple containing a hashtable representing the object describing the Azure AD service principal and
it's client secret. Where the client secret is not avilable (e.g. the service principal aleady exists) or the 
Key Vault functionality is used, '$null' will be returned for this element.

e.g.
@(
    @{ <service-principal-definition> },
    "<client-secret>"
)

#>

function Assert-AzureServicePrincipalForRbac
{
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialDisplayName', Justification='Only holds non-sensitive metadata')]
    param (
        [Parameter(ParameterSetName = 'Default', Mandatory = $true)]
        [Parameter(ParameterSetName = 'KeyVault', Mandatory = $true)]
        [string] $Name,

        [int] $PasswordLifetimeDays = 365,

        [Parameter(Mandatory = $true)]
        [string] $CredentialDisplayName,
        
        [Parameter(ParameterSetName = 'KeyVault',
                    Mandatory = $true)]
        [string] $KeyVaultName,

        [Parameter(ParameterSetName = 'KeyVault',
                    Mandatory = $true)]
        [string] $KeyVaultSecretName,

        [switch] $RotateSecret,

        [Parameter()]
        [switch] $UseApplicationCredential
    )

    # Check whether we have a valid AzPowerShell connection
    if ($PSCmdlet.ParameterSetName -eq "KeyVault") {
        # Subscription access required for key vault integration
        _EnsureAzureConnection -AzPowerShell -ErrorAction Stop | Out-Null
    }
    else {
        # No subscription-level access is required
        _EnsureAzureConnection -AzPowerShell -TenantOnly -ErrorAction Stop | Out-Null
    }

    $useKeyVault = ($PSCmdlet.ParameterSetName -eq "KeyVault")


    $credentialSecret = $null
    $existingSp = _getServicePrincipal -DisplayName $Name

    if (!$existingSp) {
        if ($PSCmdlet.ShouldProcess($Name, "Create Service Principal")) {

            # Create a new service principal
            $createParams = @{
                DisplayName = $Name
            }
            $newSp = _newServicePrincipal @createParams
            Write-Host ("Created service principal [ObjectId={0}, ApplicationId={1}]" -f $newSp.Id, $newSp.appId)
            
            # Setup the client secret/credential and store it in key vault, if necessary
            if ($UseApplicationCredential) {
                $app = _getApplicationForNewAppCredential -DisplayName $Name
                $handleCredSplat = @{ Application = $app }
            }
            else {
                $handleCredSplat = @{ ServicePrincipal = $newSp }
            }
            $credentialSecret = _handleCredential @handleCredSplat -UseKeyVault $useKeyVault
        }
    }
    else {
        Write-Host ("Service Principal '{0}' already exists [ObjectId={1}, ApplicationId={2}]" -f `
                            $Name,
                            $existingSp.Id,
                            $existingSp.appId)

        if ($useKeyVault) {
            # if using key vault, check whether the specified secret is available
            $existingSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecretName
        }

        # rotate the client secret/credential 
        if (($useKeyVault -and !$existingSecret) -or $RotateSecret) {
            if ($PSCmdlet.ShouldProcess($Name, "Rotate Service Principal Secret")) {
                Write-Host "Rotating service principal credential [UseKeyVault=$useKeyVault, KeyVaultSecretMissing=$(!$existingSecret), RotateFlag=$RotateSecret]"
                if ($UseApplicationCredential) {
                    $app = _getApplicationForNewAppCredential -DisplayName $Name
                    $handleCredSplat = @{ Application = $app }
                }
                else {
                    $handleCredSplat = @{ ServicePrincipal = $existingSp }
                }

                $credentialSecret = _handleCredential @handleCredSplat -UseKeyVault $useKeyVault
            }
        }
    }

    return ($existingSp ? $existingSp : $newSp),$credentialSecret
}

    #region Helper functions internal to the module
    function _handleCredential {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true, ParameterSetName="Application")]
            [hashtable] $Application,

            [Parameter(Mandatory=$true, ParameterSetName="ServicePrincipal")]
            [hashtable] $ServicePrincipal,

            [Parameter()]
            [bool] $UseKeyVault
        )

        if ($PSCmdlet.ParameterSetName -eq "Application") {
            Write-Verbose "Credential will be associated with the App registration"
            # Generate a new secret attached to the application registration
            $newCred = $Application | New-AzADAppCredential `
                            -EndDate ([DateTime]::Now.AddDays($PasswordLifetimeDays)) `
                            -DisplayName $CredentialDisplayName
        }
        else {
            # Generate a new secret attached to the service principal
            Write-Verbose "Credential will be associated with the Service Principal"
            $newCred = $ServicePrincipal | New-AzADServicePrincipalCredential `
                            -EndDate ([DateTime]::Now.AddDays($PasswordLifetimeDays))
        }
        

        if ($UseKeyVault) {
            $appLoginDetails = @{
                appId = $Application.appId
                password = $newCred.SecretText
                tenant = (Get-AzContext).Tenant.Id
            }
            Write-Host "Storing client secret in key vault [VaultName=$KeyVaultName, SecretName=$KeyVaultSecretName]"
            Set-AzKeyVaultSecret -VaultName $KeyVaultName `
                                 -Name $KeyVaultSecretName `
                                 -SecretValue ($appLoginDetails | ConvertTo-Json | ConvertTo-SecureString -AsPlainText -Force) `
                                 -ContentType "application/json" `
                | Out-Null

            return $null
        }
        else {
            return (ConvertFrom-SecureString $newCred.SecretText -AsPlainText)
        }
    }
    function _getApplication {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)]
            $DisplayName
        )

        $resp = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=displayName eq '$DisplayName'"
        $app = $resp.Content |
                    ConvertFrom-Json -AsHashtable -Depth 100 |
                    Select-Object -ExpandProperty value

        return $app
    }
    function _newApplication {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)]
            $DisplayName
        )

        $payload = @{ displayName = $DisplayName}
        $resp = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/applications" `
                                    -Method POST `
                                    -Payload ($payload | ConvertTo-Json)
        $newAppp = $resp.Content |
                ConvertFrom-Json -AsHashtable

        return $newApp
    }
    function _getServicePrincipal {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)]
            $DisplayName
        )

        $resp = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=displayName eq '$DisplayName'"
        $sp = $resp.Content |
                    ConvertFrom-Json -AsHashtable -Depth 100 |
                    Select-Object -ExpandProperty value

        return $sp
    }
    function _newServicePrincipal {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)]
            $DisplayName
        )

        # Check whether an application object already exists with this display name
        $app = _getApplicationForNewServicePrincipal @PSBoundParameters
        if (!$app) {
            # Create a bare application registration, as the appId
            $app = _newApplication @PSBoundParameters
        }

        # Create the service principal
        $payload = @{ appId = $app.appId}
        $newSp = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals" `
                                     -Method POST `
                                     -Payload ($payload | ConvertTo-Json)

        return ($newSp.Content | ConvertFrom-Json -AsHashtable)
    }

    # These wrapper functions are required for mocking purposes as '_getApplication' is called in 2 separate scenarios
    function _getApplicationForNewServicePrincipal {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)]
            $DisplayName
        )

        _getApplication @PSBoundParameters
    }
    function _getApplicationForNewAppCredential {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)]
            $DisplayName
        )

        _getApplication @PSBoundParameters
    }
    #endregion
