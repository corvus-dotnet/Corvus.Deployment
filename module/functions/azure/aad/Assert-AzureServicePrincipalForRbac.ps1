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

    $useKeyVault = ($PSCmdlet.ParameterSetName -eq "KeyVault")

    # Check whether we have a valid AzPowerShell connection
    # No subscription-level access is required even when using key vault, just data-plane permissions to it
    _EnsureAzureConnection -AzPowerShell -TenantOnly -ErrorAction Stop | Out-Null

    $credentialSecret = $null
    $existingSp = _getServicePrincipal -DisplayName $Name

    if (!$existingSp) {
        if ($PSCmdlet.ShouldProcess($Name, "Create Service Principal")) {

            # Create a new service principal
            $createParams = @{
                DisplayName = $Name
            }
            $newSp = _newServicePrincipal @createParams
            Write-Host ("Created service principal [ObjectId={0}, ApplicationId={1}]" -f $newSp.id, $newSp.appId)
            
            # Setup the client secret/credential and store it in key vault, if necessary
            if ($UseApplicationCredential) {
                $app = _getApplicationForNewAppCredential -DisplayName $Name
                Write-Host "Credential will be added to app registration [AppId=$($app.appId)]"
                $handleCredSplat = @{ Application = $app }
            }
            else {
                $handleCredSplat = @{ ServicePrincipal = $newSp }
                Write-Host "Credential will be added to service principal [Id=$($newSp.id)]"
            }
            $credentialSecret = _handleCredential @handleCredSplat -UseKeyVault $useKeyVault
        }
    }
    else {
        Write-Host ("Service Principal '{0}' already exists [ObjectId={1}, ApplicationId={2}]" -f `
                            $Name,
                            $existingSp.id,
                            $existingSp.appId)

        $kvSecretIsMissingOrInvalid = $false
        if ($useKeyVault) {
            # if using key vault, check whether the specified secret is available and contains the password
            $kvSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecretName
            if ($kvSecret) {
                $existingSecretJson = $kvSecret.SecretValue |
                                    ConvertFrom-SecureString -AsPlainText |
                                    ConvertFrom-Json -AsHashtable

                # Validate that the structure of the secret matches the requirements of 'azure/login@v2' GitHub Action
                $requiredKeys = "clientId", "clientSecret", "tenantId"
                $requiredKeys | ForEach-Object {
                    if (!$existingSecretJson.ContainsKey($_)) {
                        $kvSecretIsMissingOrInvalid = $true
                        Write-Warning "Key vault secret does not contain a valid '$_' field - will rotate the secret"
                    }
                }  
            }
            else {
                $kvSecretIsMissingOrInvalid = $true
            }
        }

        # rotate the client secret/credential 
        if (($useKeyVault -and $kvSecretIsMissingOrInvalid) -or $RotateSecret) {
            if ($PSCmdlet.ShouldProcess($Name, "Rotate Service Principal Secret")) {
                Write-Host "Rotating service principal credential [UseKeyVault=$useKeyVault, KeyVaultSecretMissing=$(!$existingSecret), RotateFlag=$RotateSecret]"
                if ($UseApplicationCredential) {
                    $app = _getApplicationForNewAppCredential -DisplayName $Name
                    Write-Host "Credential will be added to app registration [AppId=$($app.appId)]"
                    $handleCredSplat = @{ Application = $app }
                }
                else {
                    $handleCredSplat = @{ ServicePrincipal = $existingSp }
                    Write-Host "Credential will be added to service principal [Id=$($existingSp.id)]"
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

        $applicationMode = $PSCmdlet.ParameterSetName -eq "Application"
        if ($applicationMode) {
            Write-Verbose "Credential will be associated with the App registration"
            $baseUri = "https://graph.microsoft.com/v1.0/applications/$($Application.id)"
            # Check whether we have an existing credential with the same display name
            $existingCred = $Application.passwordCredentials |
                                Where-Object { $_.displayName -eq $CredentialDisplayName }
        }
        else {
            Write-Verbose "Credential will be associated with the Service Principal"
            $baseUri = "https://graph.microsoft.com/v1.0/servicePrincipals/$($ServicePrincipal.id)"
            # Check whether we have an existing credential with the same display name
            $existingCred = $ServicePrincipal.passwordCredentials |
                                Where-Object { $_.displayName -eq $CredentialDisplayName }
        }

        # Before adding a credential we need to check if we already added one previously - the number of
        # credentials for an object can be limited.  We should be a good citizen and remove our old one before
        # re-generating it
        if ($existingCred) {
            Write-Host "Removing existing credential [DisplayName=$CredentialDisplayName; KeyId=$($existingCred.keyId)]"
            $resp = Invoke-AzRestMethod -Uri "$baseUri/removePassword" `
                                        -Method POST `
                                        -Payload ( @{keyId = $existingCred.keyId} | ConvertTo-Json -Compress ) | _HandleRestError
        }   

        # Now we can generate the new credential - we use the REST API rather than a build cmdlet so that
        # we can set a display name for the credentials.  This improves traceability and also helps us find
        # 'our' credential in the future (e.g. when we want to rotate it)
        $body = @{
            passwordCredential = @{
                displayName = $CredentialDisplayName
                endDateTime = ([DateTime]::Now.AddDays($PasswordLifetimeDays))                    
            }
        }
        $resp = Invoke-AzRestMethod -Uri "$baseUri/addPassword" `
                                    -Method POST `
                                    -Payload ($body | ConvertTo-Json -Compress) | _HandleRestError
        $newCred = $resp.Content |
                        ConvertFrom-Json -AsHashtable
        

        # Store the credentials in key vault, if required
        if ($UseKeyVault) {
            # This format of secret is compatible with 'azure/login' GitHub Action, originally this used a format
            # that matched the output 'az ad sp create-for-rbac' command, however this is no longer the case, so we
            # use the format documented below.
            # REF: https://github.com/azure/login?tab=readme-ov-file#creds
            $appLoginDetails = @{
                clientId = ($applicationMode ? $Application.appId : $ServicePrincipal.appId)
                clientSecret = $newCred.secretText
                tenantId = (Get-AzContext).Tenant.Id
            }
            Write-Host "Storing client secret in key vault [VaultName=$KeyVaultName, SecretName=$KeyVaultSecretName]"
            Set-AzKeyVaultSecret -VaultName $KeyVaultName `
                                 -Name $KeyVaultSecretName `
                                 -SecretValue ($appLoginDetails | ConvertTo-Json | ConvertTo-SecureString -AsPlainText -Force) `
                                 -ContentType "application/json" `
                                 -Expires $body.passwordCredential.endDateTime `
                | Out-Null

            return $null
        }
        else {
            return $newCred.secretText
        }
    }
    function _getApplication {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)]
            $DisplayName
        )

        $resp = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=displayName eq '$DisplayName'" | _HandleRestError
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
        Write-Verbose "Creating app registation object [DisplayName=$DisplayName]"
        $resp = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/applications" `
                                    -Method POST `
                                    -Payload ($payload | ConvertTo-Json) | _HandleRestError
        $newApp = $resp.Content |
                    ConvertFrom-Json -AsHashtable
        Write-Verbose "Created app registation object [AppId=$($newApp.appId); Id=$($newApp.id)]"

        return $newApp
    }
    function _getServicePrincipal {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)]
            $DisplayName
        )

        $resp = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=displayName eq '$DisplayName'" | _HandleRestError
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
        Write-Verbose "Creating service principal object [AppId=$($app.appId)]"
        $resp = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals" `
                                     -Method POST `
                                     -Payload ($payload | ConvertTo-Json) | _HandleRestError
        $newSp = $resp.Content |
                    ConvertFrom-Json -AsHashtable
        Write-Verbose "Created service principal object [Id=$($newSp.id)]"

        return $newSp
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
