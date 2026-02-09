BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $sut = (Split-Path -Leaf $PSCommandPath).Replace(".Tests.ps1", ".ps1")

    . "$here/$sut"

    # Make external dependencies available for mocking
    function Get-AzKeyVaultSecret {}
    function Set-AzKeyVaultSecret {}
    function Get-AzContext {}
    function Invoke-AzRestMethod { param($Uri, $Method, $Payload) }
    function _EnsureAzureConnection {}
    function _HandleRestError { param([Parameter(ValueFromPipeline=$true)]$Response) return $Response }
    function Write-Host {}
}

Describe "Assert-AzureServicePrincipalForRbac Tests" {

    BeforeAll {
        # Setup mock objects
        $mockSp =  @{
            id = '00000000-0000-0000-0000-000000000001'
            appId = [guid]::Empty
            displayName = "mock-sp"
            passwordCredentials = @()
        }
        $mockApp =  @{
            id = '00000000-0000-0000-0000-000000000002'
            appId = [guid]::Empty
            displayName = "mock-sp"
            passwordCredentials = @()
        }

        # Global mocks
        Mock Invoke-AzRestMethod { @{ Content = (@{ secretText = "mock-secret" } | ConvertTo-Json) } } -ParameterFilter { $Uri.EndsWith("addPassword") }
        Mock Invoke-AzRestMethod {} -ParameterFilter { $Uri.EndsWith("removePassword") }
        Mock Set-AzKeyVaultSecret {}
        Mock Get-AzContext { @{ Tenant = @{Id = "00000000-0000-0000-0000-000000000009"} } }
    }

    Context "Not using Key Vault" {

        BeforeAll {
            Mock Get-AzKeyVaultSecret {}
        }

        Context "Using service principal credentials" {

            Describe "Creating a new service principal with default options" {

                BeforeAll {
                    Mock Invoke-AzRestMethod { @{ Content = ($mockSp | ConvertTo-Json) } } -ParameterFilter { $Uri.EndsWith('servicePrincipals') }
                    Mock _newApplication { $mockApp }

                    Mock _getApplication {}
                    Mock _getServicePrincipal {}

                    $res = Assert-AzureServicePrincipalForRbac `
                                -Name "mock-sp" `
                                -CredentialDisplayName "mock-credential"
                }

                It "should create a new service principal" {
                    $res.Count | Should -Be 2
                    $res[0].id | Should -Be '00000000-0000-0000-0000-000000000001'
                    $res[1] | Should -Be "mock-secret"

                    Should -Invoke _getApplication -Times 1 -Scope Describe -ParameterFilter { $DisplayName -eq 'mock-sp' }
                    Should -Invoke _newApplication -Times 1 -Scope Describe -ParameterFilter { $DisplayName -eq 'mock-sp' }
                    Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Describe -ParameterFilter { $Uri.EndsWith('servicePrincipals') -and $Method -eq 'POST' -and $Payload -imatch '"appId": "00000000-0000-0000-0000-000000000000"' }
                }

                It "should not check for an existing secret in the key vault" {
                    Should -Invoke Get-AzKeyVaultSecret -Times 0 -Scope Describe     # the SP does not exist so we shouldn't be checking for ean existing secret in key vault
                }

                It "should create a new service principal credential" {
                    Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "servicePrincipals" }
                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "applications" }
                }

                It "should not update the key vault secret" {
                    Should -Invoke Set-AzKeyVaultSecret -Times 0 -Scope Describe
                }
            }
            Describe "Updating an existing service principal with default options" {

                BeforeAll {
                    Mock _getServicePrincipal { $mockSp }
                    Mock _getApplication { $mockApp }

                    Mock _newApplication {}
                    Mock _handleCredential {}
                    Mock _newServicePrincipal {}

                    $res = Assert-AzureServicePrincipalForRbac `
                                -Name "mock-sp" `
                                -CredentialDisplayName "mock-credential"
                }

                It "should not create a new service principal" {
                    Should -Invoke _newApplication -Times 0 -Scope Describe
                    Should -Invoke _newServicePrincipal -Times 0 -Scope Describe
                }

                It "should not check for an existing secret in the key vault" {
                    Should -Invoke Get-AzKeyVaultSecret -Times 0 -Scope Describe     # the SP does not exist so we shouldn't be checking for ean existing secret in key vault
                }

                It "should not update the service principal credential" {
                    $res.Count | Should -Be 2
                    $res[0].id | Should -Be '00000000-0000-0000-0000-000000000001'
                    $res[1] | Should -Be $null

                    Should -Invoke _getApplication -Times 0 -Scope Describe
                    Should -Invoke _handleCredential -Times 0 -Scope Describe
                }

                It "should not update the key vault secret" {
                    Should -Invoke Set-AzKeyVaultSecret -Times 0 -Scope Describe
                }
            }

            Describe "Updating an existing service principal with the 'RotateSecret' option" {

                BeforeAll {
                    Mock _getServicePrincipal { $mockSp }
                    Mock _getApplication { $mockApp }

                    Mock _newApplication {}
                    Mock _newServicePrincipal {}

                    $res = Assert-AzureServicePrincipalForRbac `
                                -Name "mock-sp" `
                                -CredentialDisplayName "mock-credential" `
                                -RotateSecret
                }

                It "should not create a new service principal" {
                    Should -Invoke _newApplication -Times 0 -Scope Describe
                    Should -Invoke _newServicePrincipal -Times 0 -Scope Describe
                }

                It "should not check for an existing secret in the key vault" {
                    Should -Invoke Get-AzKeyVaultSecret -Times 0 -Scope Describe     # the SP does not exist so we shouldn't be checking for ean existing secret in key vault
                }

                It "should update the service principal credential" {
                    $res.Count | Should -Be 2
                    $res[0].id | Should -Be '00000000-0000-0000-0000-000000000001'
                    $res[1] | Should -Be "mock-secret"

                    Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "servicePrincipals" }
                    Should -Invoke _getServicePrincipal -Times 1 -Scope Describe
                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "applications" }
                    Should -Invoke _getApplication -Times 0 -Scope Describe
                }

                It "should not update the key vault secret" {
                    Should -Invoke Set-AzKeyVaultSecret -Times 0 -Scope Describe
                }
            }
        }

        Context "Using app registration credentials" {

            Describe "Creating a new service principal with default options" {

                BeforeAll {
                    Mock Invoke-AzRestMethod { @{ Content = ($mockSp | ConvertTo-Json) } }
                    Mock _newApplication { $mockApp }
                    Mock _getApplication {}
                    Mock _getApplicationForNewAppCredential { $mockApp }

                    Mock _getServicePrincipal {}

                    $res = Assert-AzureServicePrincipalForRbac `
                                -Name "mock-sp" `
                                -CredentialDisplayName "mock-credential" `
                                -UseApplicationCredential
                }

                It "should create a new service principal" {
                    $res.Count | Should -Be 2
                    $res[0].id | Should -Be '00000000-0000-0000-0000-000000000001'
                    $res[1] | Should -Be "mock-secret"

                    Should -Invoke _getApplication -Times 1 -Scope Describe -ParameterFilter { $DisplayName -eq 'mock-sp' }
                    Should -Invoke _newApplication -Times 1 -Scope Describe -ParameterFilter { $DisplayName -eq 'mock-sp' }
                    Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Describe -ParameterFilter { $Uri.EndsWith('servicePrincipals') -and $Method -eq 'POST' -and $Payload -imatch '"appId": "00000000-0000-0000-0000-000000000000"' }
                }

                It "should not check for an existing secret in the key vault" {
                    Should -Invoke Get-AzKeyVaultSecret -Times 0 -Scope Describe     # the SP does not exist so we shouldn't be checking for ean existing secret in key vault
                }

                It "should create a new application credential" {
                    Should -Invoke _getApplicationForNewAppCredential -Times 1 -Scope Describe -ParameterFilter { $DisplayName -eq 'mock-sp' }
                    Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "applications" }

                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "servicePrincipals" }
                }

                It "should not update the key vault secret" {
                    Should -Invoke Set-AzKeyVaultSecret -Times 0 -Scope Describe
                }
            }

            Describe "Updating an existing service principal with default options" {

                BeforeAll {
                    Mock _getServicePrincipal { $mockSp }
                    Mock _getApplication { $mockApp }

                    Mock _newApplication {}
                    Mock _handleCredential {}
                    Mock _newServicePrincipal {}

                    $res = Assert-AzureServicePrincipalForRbac `
                                -Name "mock-sp" `
                                -CredentialDisplayName "mock-credential" `
                                -UseApplicationCredential
                }

                It "should not create a new service principal" {
                    Should -Invoke _newApplication -Times 0 -Scope Describe
                    Should -Invoke _newServicePrincipal -Times 0 -Scope Describe
                }

                It "should not check for an existing secret in the key vault" {
                    Should -Invoke Get-AzKeyVaultSecret -Times 0 -Scope Describe     # the SP does not exist so we shouldn't be checking for ean existing secret in key vault
                }

                It "should not update the application credential" {
                    $res.Count | Should -Be 2
                    $res[0].id | Should -Be '00000000-0000-0000-0000-000000000001'
                    $res[1] | Should -Be $null

                    Should -Invoke _getApplication -Times 0 -Scope Describe
                    Should -Invoke _handleCredential -Times 0 -Scope Describe
                }

                It "should not update the key vault secret" {
                    Should -Invoke Set-AzKeyVaultSecret -Times 0 -Scope Describe
                }
            }

            Describe "Updating an existing service principal with the 'RotateSecret' option" {

                BeforeAll {
                    Mock _getServicePrincipal { $mockSp }
                    Mock _getApplication { $mockApp }

                    Mock _newApplication {}
                    Mock _newServicePrincipal {}

                    $res = Assert-AzureServicePrincipalForRbac `
                                -Name "mock-sp" `
                                -CredentialDisplayName "mock-credential" `
                                -RotateSecret `
                                -UseApplicationCredential
                }

                It "should not create a new service principal" {
                    Should -Invoke _newApplication -Times 0 -Scope Describe
                    Should -Invoke _newServicePrincipal -Times 0 -Scope Describe
                }

                It "should not check for an existing secret in the key vault" {
                    Should -Invoke Get-AzKeyVaultSecret -Times 0 -Scope Describe     # the SP does not exist so we shouldn't be checking for ean existing secret in key vault
                }

                It "should update the application credential" {
                    $res.Count | Should -Be 2
                    $res[0].id | Should -Be '00000000-0000-0000-0000-000000000001'
                    $res[1] | Should -Be "mock-secret"

                    Should -Invoke _getServicePrincipal -Times 1 -Scope Describe
                    Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "applications" }

                    Should -Invoke _getApplication -Times 1 -Scope Describe
                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "servicePrincipals" }
                }

                It "should not update the key vault secret" {
                    Should -Invoke Set-AzKeyVaultSecret -Times 0 -Scope Describe
                }
            }
        }
    }


    Context "Key Vault Support" {

        BeforeAll {
            $mockSavedSecret = @{
                clientId = "mockAppId"
                clientSecret = "mockSecret"
                tenantId = "mockTenantId"
            }
            Mock Get-AzKeyVaultSecret { @{ SecretValue = ($mockSavedSecret | ConvertTo-Json | ConvertTo-SecureString -AsPlainText) } }
        }

        Context "Using service principal credentials" {

            Describe "Creating a new service principal with default options" {

                BeforeAll {
                    Mock Invoke-AzRestMethod { @{ Content = ($mockSp | ConvertTo-Json) } }
                    Mock _newApplication { $mockApp }

                    Mock _getApplication {}
                    Mock _getServicePrincipal {}

                    $res = Assert-AzureServicePrincipalForRbac `
                                -Name "mock-sp" `
                                -CredentialDisplayName "mock-credential" `
                                -KeyVaultName "mock-keyvault" `
                                -KeyVaultSecretName "mock-secret-name"
                }

                It "should create a new service principal" {
                    Should -Invoke _newApplication -Times 1 -Scope Describe -ParameterFilter { $DisplayName -eq 'mock-sp' }
                    Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Describe -ParameterFilter { $Uri.EndsWith('servicePrincipals') -and $Method -eq 'POST' -and $Payload -imatch '"appId": "00000000-0000-0000-0000-000000000000"' }
                }

                It "should not check for an existing secret in the key vault" {
                    Should -Invoke Get-AzKeyVaultSecret -Times 0 -Scope Describe     # the SP does not exist so we shouldn't be checking for ean existing secret in key vault
                }

                It "should create a new service principal credential" {
                    $res.Count | Should -Be 2
                    $res[0].id | Should -Be '00000000-0000-0000-0000-000000000001'
                    $res[1] | Should -Be $null

                    Should -Invoke _getApplication -Times 1 -Scope Describe -ParameterFilter { $DisplayName -eq 'mock-sp' }
                    Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "servicePrincipals" }
                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "applications" }
                }

                It "should store the secret the key vault" {
                    Should -Invoke Set-AzKeyVaultSecret -Times 1 -Scope Describe     # the key vault should be updated with new secret
                }
            }

            Describe "Update an existing service principal with default options" {

                BeforeAll {
                    Mock _getServicePrincipal { $mockSp }
                    Mock _getApplication { $mockApp }

                    Mock _newApplication {}
                    Mock _newServicePrincipal {}

                    $res = Assert-AzureServicePrincipalForRbac `
                                -Name "mock-sp" `
                                -CredentialDisplayName "mock-credential" `
                                -KeyVaultName "mock-keyvault" `
                                -KeyVaultSecretName "mock-secret-name"
                }

                It "should not create a new service principal" {
                    Should -Invoke _newApplication -Times 0 -Scope Describe
                    Should -Invoke _newServicePrincipal -Times 0 -Scope Describe
                }

                It "should check for an existing secret in the key vault" {
                    Should -Invoke Get-AzKeyVaultSecret -Times 1 -Scope Describe     # the SP exists so we should check the key vault
                }

                It "should not create a new service principal credential" {
                    $res.Count | Should -Be 2
                    $res[0].id | Should -Be '00000000-0000-0000-0000-000000000001'
                    $res[1] | Should -Be $null

                    Should -Invoke _getServicePrincipal -Times 1 -Scope Describe
                    Should -Invoke _getApplication -Times 0 -Scope Describe
                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "servicePrincipals" }
                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "applications" }
                }

                It "should not update the key vault secret" {
                    Should -Invoke Set-AzKeyVaultSecret -Times 0 -Scope Describe     # the key vault should be updated with new secret
                }
            }

            Describe "Update an existing service principal with the 'RotateSecret' option" {

                BeforeAll {
                    Mock _getServicePrincipal { $mockSp }
                    Mock _getApplication { $mockApp }

                    Mock _newApplication {}
                    Mock _newServicePrincipal {}

                    $res = Assert-AzureServicePrincipalForRbac `
                                -Name "mock-sp" `
                                -CredentialDisplayName "mock-credential" `
                                -KeyVaultName "mock-keyvault" `
                                -KeyVaultSecretName "mock-secret-name" `
                                -RotateSecret
                }

                It "should not create a new service principal" {
                    Should -Invoke _newApplication -Times 0 -Scope Describe
                    Should -Invoke _newServicePrincipal -Times 0 -Scope Describe
                }

                It "should check for an existing secret in the key vault" {
                    Should -Invoke Get-AzKeyVaultSecret -Times 1 -Scope Describe     # the SP exists so we should check the key vault
                }

                It "should create a new service principal credential" {
                    $res.Count | Should -Be 2
                    $res[0].id | Should -Be '00000000-0000-0000-0000-000000000001'
                    $res[1] | Should -Be $null

                    Should -Invoke _getServicePrincipal -Times 1 -Scope Describe
                    Should -Invoke _getApplication -Times 0 -Scope Describe
                    Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "servicePrincipals" }
                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "applications" }
                }

                It "should update the key vault secret" {
                    Should -Invoke Set-AzKeyVaultSecret -Times 1 -Scope Describe     # the key vault should be updated with new secret
                }
            }
        }

        Context "Using app registration credentials" {
            Describe "Creating a new service principal with default options" {

                BeforeAll {
                    Mock Invoke-AzRestMethod { @{ Content = ($mockSp | ConvertTo-Json) } }
                    Mock _newApplication { $mockApp }

                    Mock _getApplicationForNewServicePrincipal {}
                    Mock _getApplicationForNewAppCredential { $mockApp }
                    Mock _getServicePrincipal {}

                    $res = Assert-AzureServicePrincipalForRbac `
                                -Name "mock-sp" `
                                -CredentialDisplayName "mock-credential" `
                                -KeyVaultName "mock-keyvault" `
                                -KeyVaultSecretName "mock-secret-name" `
                                -UseApplicationCredential
                }

                It "should create a new service principal" {
                    Should -Invoke _getApplicationForNewServicePrincipal -Times 1 -Scope Describe
                    Should -Invoke _newApplication -Times 1 -Scope Describe -ParameterFilter { $DisplayName -eq 'mock-sp' }
                    Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Describe -ParameterFilter { $Uri.EndsWith('servicePrincipals') -and $Method -eq 'POST' -and $Payload -imatch '"appId": "00000000-0000-0000-0000-000000000000"' }
                }

                It "should not check for an existing secret in the key vault" {
                    Should -Invoke Get-AzKeyVaultSecret -Times 0 -Scope Describe     # the SP does not exist so we shouldn't be checking for ean existing secret in key vault
                }

                It "should create a new service principal credential" {
                    $res.Count | Should -Be 2
                    $res[0].id | Should -Be '00000000-0000-0000-0000-000000000001'
                    $res[1] | Should -Be $null

                    Should -Invoke _getApplicationForNewAppCredential -Times 1 -Scope Describe -ParameterFilter { $DisplayName -eq 'mock-sp' }
                    Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "applications" }
                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "servicePrincipals" }
                }

                It "should store the secret the key vault" {
                    Should -Invoke Set-AzKeyVaultSecret -Times 1 -Scope Describe     # the key vault should be updated with new secret
                }
            }

            Describe "Update an existing service principal with default options" {

                BeforeAll {
                    Mock _getServicePrincipal { $mockSp }
                    Mock _getApplication { $mockApp }

                    Mock _newApplication {}
                    Mock _newServicePrincipal {}

                    $res = Assert-AzureServicePrincipalForRbac `
                                -Name "mock-sp" `
                                -CredentialDisplayName "mock-credential" `
                                -KeyVaultName "mock-keyvault" `
                                -KeyVaultSecretName "mock-secret-name" `
                                -UseApplicationCredential
                }

                It "should not create a new service principal" {
                    Should -Invoke _newApplication -Times 0 -Scope Describe
                    Should -Invoke _newServicePrincipal -Times 0 -Scope Describe
                }

                It "should check for an existing secret in the key vault" {
                    Should -Invoke Get-AzKeyVaultSecret -Times 1 -Scope Describe     # the SP exists so we should check the key vault
                }

                It "should not create a new service principal credential" {
                    $res.Count | Should -Be 2
                    $res[0].id | Should -Be '00000000-0000-0000-0000-000000000001'
                    $res[1] | Should -Be $null

                    Should -Invoke _getServicePrincipal -Times 1 -Scope Describe
                    Should -Invoke _getApplication -Times 0 -Scope Describe
                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "applications" }
                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "servicePrincipals" }
                }

                It "should not update the key vault secret" {
                    Should -Invoke Set-AzKeyVaultSecret -Times 0 -Scope Describe     # the key vault should be updated with new secret
                }
            }

            Describe "Update an existing service principal with the 'RotateSecret' option" {

                BeforeAll {
                    Mock _getServicePrincipal { $mockSp }
                    Mock _getApplication { $mockApp }

                    Mock _newApplication {}
                    Mock _newServicePrincipal {}

                    $res = Assert-AzureServicePrincipalForRbac `
                                -Name "mock-sp" `
                                -CredentialDisplayName "mock-credential" `
                                -KeyVaultName "mock-keyvault" `
                                -KeyVaultSecretName "mock-secret-name" `
                                -RotateSecret `
                                -UseApplicationCredential
                }

                It "should not create a new service principal" {
                    Should -Invoke _newApplication -Times 0 -Scope Describe
                    Should -Invoke _newServicePrincipal -Times 0 -Scope Describe
                }

                It "should check for an existing secret in the key vault" {
                    Should -Invoke Get-AzKeyVaultSecret -Times 1 -Scope Describe     # the SP exists so we should check the key vault
                }

                It "should create a new service principal credential" {
                    $res.Count | Should -Be 2
                    $res[0].id | Should -Be '00000000-0000-0000-0000-000000000001'
                    $res[1] | Should -Be $null

                    Should -Invoke _getServicePrincipal -Times 1 -Scope Describe
                    Should -Invoke _getApplication -Times 1 -Scope Describe
                    Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "applications" }
                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "servicePrincipals" }
                }

                It "should update the key vault secret" {
                    Should -Invoke Set-AzKeyVaultSecret -Times 1 -Scope Describe     # the key vault should be updated with new secret
                }
            }
        }

        Context "Kay Vault secret validation" {

            Describe "Existing secret storing the 'clientSecret' property without 'RotateSecret' option" {
                BeforeAll {
                    $mockSavedSecret = @{
                        clientId = "mockAppId"
                        clientSecret = "mockSecret"
                        tenantId = "mockTenantId"
                    }
                    Mock Get-AzKeyVaultSecret { @{ SecretValue = ($mockSavedSecret | ConvertTo-Json | ConvertTo-SecureString -AsPlainText) } }

                    Mock _getServicePrincipal { $mockSp }
                    Mock _getApplication { $mockApp }

                    Mock _newApplication {}
                    Mock _newServicePrincipal {}

                    $res = Assert-AzureServicePrincipalForRbac `
                                -Name "mock-sp" `
                                -CredentialDisplayName "mock-credential" `
                                -KeyVaultName "mock-keyvault" `
                                -KeyVaultSecretName "mock-secret-name"
                }

                It "should not create a new service principal" {
                    Should -Invoke _newApplication -Times 0 -Scope Describe
                    Should -Invoke _newServicePrincipal -Times 0 -Scope Describe
                }

                It "should check for an existing secret in the key vault" {
                    Should -Invoke Get-AzKeyVaultSecret -Times 1 -Scope Describe     # the SP exists so we should check the key vault
                }

                It "should not create a new service principal credential" {
                    $res.Count | Should -Be 2
                    $res[0].id | Should -Be '00000000-0000-0000-0000-000000000001'
                    $res[1] | Should -Be $null

                    Should -Invoke _getServicePrincipal -Times 1 -Scope Describe
                    Should -Invoke _getApplication -Times 0 -Scope Describe
                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "servicePrincipals" }
                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "applications" }
                }

                It "should not update the key vault secret" {
                    Should -Invoke Set-AzKeyVaultSecret -Times 0 -Scope Describe     # the key vault should be updated with new secret
                }
            }
            Describe "Existing invalid secret in key vault without 'RotateSecret' option" {
                BeforeAll {
                    $mockSavedSecret = @{
                        clientId = "mockAppId"
                        tenantId = "mockTenantId"
                    }
                    Mock Get-AzKeyVaultSecret { @{ SecretValue = ($mockSavedSecret | ConvertTo-Json | ConvertTo-SecureString -AsPlainText) } }
                    Mock Write-Warning {}

                    Mock _getServicePrincipal { $mockSp }
                    Mock _getApplication { $mockApp }

                    Mock _newApplication {}
                    Mock _newServicePrincipal {}

                    $res = Assert-AzureServicePrincipalForRbac `
                                -Name "mock-sp" `
                                -CredentialDisplayName "mock-credential" `
                                -KeyVaultName "mock-keyvault" `
                                -KeyVaultSecretName "mock-secret-name"
                }

                It "should not create a new service principal" {
                    Should -Invoke _newApplication -Times 0 -Scope Describe
                    Should -Invoke _newServicePrincipal -Times 0 -Scope Describe
                }

                It "should check for an existing secret in the key vault" {
                    Should -Invoke Get-AzKeyVaultSecret -Times 1 -Scope Describe     # the SP exists so we should check the key vault
                }

                It "should log a warning message" {
                    Should -Invoke Write-Warning -Times 1 -Scope Describe
                }

                It "should create a new service principal credential" {
                    $res.Count | Should -Be 2
                    $res[0].id | Should -Be '00000000-0000-0000-0000-000000000001'
                    $res[1] | Should -Be $null

                    Should -Invoke _getServicePrincipal -Times 1 -Scope Describe
                    Should -Invoke _getApplication -Times 0 -Scope Describe
                    Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "servicePrincipals" }
                    Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Describe -ParameterFilter { $Uri.EndsWith("addPassword") -and $Uri -match "applications" }
                }

                It "should update the key vault secret" {
                    Should -Invoke Set-AzKeyVaultSecret -Times 1 -Scope Describe     # the key vault should be updated with new secret
                }
            }
        }
    }
}
