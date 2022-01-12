# <copyright file="Assert-AzureServicePrincipalForRbac.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that an Azure AD service principal exists, creating if necessary.  Optionally storing the credential
in Azure Key Vault.

.DESCRIPTION
Ensures that a suitable Azure AD application & service principal exists.  Optionally storing the credential
in Azure Key Vault.

.PARAMETER Name
The display name of the Azure AD service principal.

.PARAMETER KeyVaultName
The key vault where that service principal password will be stored.

.PARAMETER KeyVaultSecretName
The key vault secret name that service principal password will be stored in.

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
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,
        
        [Parameter(ParameterSetName = 'KeyVault',
                    Mandatory = $true)]
        [string] $KeyVaultName,

        [Parameter(ParameterSetName = 'KeyVault',
                    Mandatory = $true)]
        [string] $KeyVaultSecretName

    )

    _EnsureAzureConnection -AzPowerShell | Out-Null

    $spSecret = $null
    $existingSp = Get-AzADServicePrincipal -DisplayName $Name

    if (!$existingSp) {
        if ($PSCmdlet.ShouldProcess($Name, "Create Service Principal")) {

            # Create a new service principal
            $newSp = New-AzADServicePrincipal -DisplayName $Name
            Write-Host ("Complete - ObjectId={0},ApplicationId={1}" -f $newSp.Id, $newSp.AppId)
            
            # do the required credential handling
            if ($PSCmdlet.ParameterSetName -eq "KeyVault") {
                # Store the secret in key vault
                Set-AzKeyVaultSecret -VaultName $KeyVaultName `
                                     -Name $KeyVaultSecretName `
                                     -SecretValue ($newSp.PasswordCredentials.SecretText | ConvertTo-SecureString -AsPlainText -Force) `
                                     -ContentType "text/plain" `
                    | Out-Null
            }
            else {
                # retain previous behaviour
                $spSecret = $newSp.PasswordCredentials.SecretText
            }
        }
    }
    else {
        Write-Host ("Service Principal '{0}' already exists - skipping [ObjectId={1},ApplicationId={2}]" -f $existingSp.AppDisplayName, $existingSp.Id, $existingSp.AppId)
    }

    return ($existingSp ? $existingSp : $newSp),$spSecret
}
