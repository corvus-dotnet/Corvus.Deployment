# <copyright file="_ResolveDeploymentConfigValues.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".ps1")

. "$here\$sut"

# Import other dependency functions
. $here/../azure/_EnsureAzureConnection.ps1

Describe "_ResolveDeploymentConfigValues Tests" {

    Context "No resolvable values" {

        $mockConfig = @{
            foo = "bar"
            bar = $true
            foobar = 2
        }

        $res = _ResolveDeploymentConfigValues $mockConfig

        It "should return unmodified configuration values" {
            $res | should -be $mockConfig
        }
    }

    Context "Key Vault SecretUri Handler" {

        $mockSecretUri = "https://myvault.vault.azure.net/secrets/mysecret"
        $mockConfig = @{
            foo = "bar"
            bar = $true
            foobar = 2
            passwd = "@Microsoft.KeyVault(SecretUri=$mockSecretUri)" 
        }

        Mock _EnsureAzureConnection {}
        Mock _invokeHandler { "secret-password" }
        
        $res = _ResolveDeploymentConfigValues $mockConfig

        It "should call the KeyVaultSecretUri handler" {
            Assert-MockCalled _invokeHandler -Times 1 -ParameterFilter { $HandlerName -eq "_keyVaultSecretUriHandler" -and $ValueToResolve -eq $mockSecretUri }
        }

        It "should update the configuration object with the resolved value" {
            $res.passwd | should -be "secret-password"
        }
    }
}

Describe "_ResolveDeploymentConfigValues Integration Tests" -Tag Integration {

    BeforeAll {
        $script:testRgName = (New-Guid).Guid
        $script:testKvName = "x{0}" -f $testRgName.Replace("-","").Substring(0,22)
        $script:testSecretValue = (New-Guid).Guid | ConvertTo-SecureString -AsPlainText
        $script:testSecretName = "test-secret"

        Write-Host "Provisioning test resources..."
        New-AzResourceGroup -Name $testRgName -Location UKSouth | Out-Null
        $kv = New-AzKeyVault -ResourceGroupName $testRgName -Name $testKvName -Location UKSouth
        $script:kvSecret = Set-AzKeyVaultSecret -VaultName $kv.VaultName -Name $testSecretName -SecretValue $testSecretValue
    }
    AfterAll {
        Write-Host "Removing test resources..."
        Remove-AzResourceGroup -ResourceGroupName $testRgName -Force | Out-Null
        Remove-AzKeyVault -VaultName $testKvName -Location UKSouth -InRemovedState -Force | Out-Null
    }

    Context "Key Vault SecretUri Handler" {
        Mock _EnsureAzureConnection {}

        $mockConfig = @{
            username = "someuser"
            password = "@Microsoft.KeyVault(SecretUri=$($kvSecret.Id))" 
        }
        
        $res = _ResolveDeploymentConfigValues $mockConfig

        It "should resolve the correct value from Key Vault" {
            (ConvertFrom-SecureString -AsplainText $mockConfig.password)  | should -be (ConvertFrom-SecureString -AsplainText $testSecretValue)
        }
    }
}