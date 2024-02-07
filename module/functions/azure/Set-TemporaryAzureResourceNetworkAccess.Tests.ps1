$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".ps1")

. "$here\$sut"

# load the handler implementations
Get-ChildItem "$here\_azureResourceNetworkAccessHandlers\*.ps1" |
    ForEach-Object { . $_.FullName }

# Suppress the connection validation logic
function _EnsureAzureConnection {}

Describe "Set-TemporaryAzureResourceNetworkAccess Integration Tests" -Tag Integration {

    BeforeAll {
        $currentUser = Get-AzADUser -SignedIn
        # Generate stable user-specific naming conventions that will work for users and service principals
        $suffix = ($currentUser.Id -replace "-","").SubString(0,20)
        $rg = "pester-tempnetaccess-$($currentUser.Id)"
        $location = "uksouth"

        New-AzResourceGroup -ResourceGroupName $rg -Location $location -Tag @{Environment = "Pester"} -Force
    }

    AfterAll {
        Write-Host "`n`nCleaning-up Azure test resources..."
        Remove-AzResourceGroup -ResourceGroupName $rg -Force
        Remove-AzKeyVault -VaultName $suffix -Location $location -InRemovedState -Force
    }

    Context "Azure Storage Account" {
        Mock Write-Host {}
    
        BeforeAll {
            # Create storage account
            $saParams = @{
                ResourceGroupName = $rg
                Name = $suffix
                Tag = @{Environment = "Pester"}
                Kind = "StorageV2"
                Sku = "Standard_LRS"
                AccessTier = "Hot"
                Location = $location
                MinimumTlsVersion = "TLS1_2"
                EnableHttpsTrafficOnly = $true
            }
            New-AzStorageAccount @saParams -ErrorAction Ignore | Out-Null
            $sa = Get-AzStorageAccount -ResourceGroupName $saParams.ResourceGroupName -Name $saParams.Name
            
            # Ensure the test has the necessary data-plane permissions
            New-AzRoleAssignment -Scope $sa.Id -RoleDefinitionName "Storage Blob Data Contributor" -ObjectId $currentUser.Id -ErrorAction Ignore
            
            # Lockdown access to the storage account
            $sa | Update-AzStorageAccountNetworkRuleSet -DefaultAction Deny -Bypass None

            # Pause to ensure the change has taken effect
            Write-Host "Waiting for storage firewall to update..."
            Start-Sleep -Seconds 30
        }

        It "should not have permissions before enabling temporary network access" {
            { Get-AzStorageBlob -Container "foo" -Blob "foo/bar.txt" -Context $sa.Context -ErrorAction Stop } |
                Should -Throw "This request is not authorized to perform this operation."
        }
        
        It "should not be able to connect immediately when not waiting for the temporary network access" {
            Set-TemporaryAzureResourceNetworkAccess -ResourceType StorageAccount -ResourceGroupName $rg -ResourceName $suffix

            { Get-AzStorageBlob -Container "foo" -Blob "foo/bar.txt" -Context $sa.Context -ErrorAction Stop } |
                Should -Throw "This request is not authorized to perform this operation."
        }

        It "should connect successfully after waiting for the temporary network access" {
            Start-Sleep -Seconds 30
            
            { Get-AzStorageBlob -Container "foo" -Blob "foo/bar.txt" -Context $sa.Context -ErrorAction Stop } |
                Should -Throw "Can not find blob 'foo/bar.txt' in container 'foo', or the blob type is unsupported."
        }
        
        It "should not have permissions after using the 'Revoke' flag" {
            Set-TemporaryAzureResourceNetworkAccess -ResourceType StorageAccount -ResourceGroupName $rg -ResourceName $suffix -Revoke -Wait

            { Get-AzStorageBlob -Container "foo" -Blob "foo/bar.txt" -Context $sa.Context -ErrorAction Stop } |
                Should -Throw "This request is not authorized to perform this operation."
        }
    }

    Context "Azure SQL Server" {
        Mock Write-Host {}
    
        BeforeAll {
            # Create SQL server
            $sqlParams = @{
                ResourceGroupName = $rg
                ServerName = $suffix
                Tags = @{Environment = "Pester"}
                EnableActiveDirectoryOnlyAuthentication = $true
                ExternalAdminName = $currentUser.UserPrincipalName
                MinimalTlsVersion = "1.2"
                Location = $location
            }
            New-AzSqlServer @sqlParams -ErrorAction Ignore | Out-Null
            $server = Get-AzSqlServer -ResourceGroupName $sqlParams.ResourceGroupName -ServerName $sqlParams.ServerName
    
            # Prepare the test SQL query
            $sqlCmd = {
                Invoke-Sqlcmd `
                    -Query "select * from sys.tables" `
                    -ServerInstance "$suffix.database.windows.net" `
                    -Database master `
                    -AccessToken (Get-AzAccessToken -ResourceUrl "https://database.windows.net").Token `
                    -AbortOnError `
                    -ErrorAction Stop
            }
        }
    
        It "should not have permissions before enabling temporary network access" {
            { $sqlCmd.Invoke() } | Should -Throw
        }
       
        It "should connect successfully after enabling temporary network access" {
            Set-TemporaryAzureResourceNetworkAccess -ResourceType SqlServer -ResourceGroupName $rg -ResourceName $suffix -Wait
    
            $res = $sqlCmd.Invoke()
            $res | Should -Not -BeNullOrEmpty
        }
       
        It "should not have permissions after using the 'Revoke' flag" {
            Set-TemporaryAzureResourceNetworkAccess -ResourceType SqlServer -ResourceGroupName $rg -ResourceName $suffix -Revoke -Wait
    
            { $sqlCmd.Invoke() } | Should -Throw
        }
    }

    Context "Azure Web App" {
        Mock Write-Host {}

        BeforeAll {
            # Create the App Service
            $aspParams = @{
                ResourceGroupName = $rg
                ResourceType = "microsoft.web/serverfarms"
                ResourceName = $suffix
                Sku = @{
                    name = "B1"
                    tier = "Basic"
                    family = "B"
                    capacity = "1"
                }
                Kind = "Linux"
                Properties = @{ Reserved = $true }
                Location = $location
                Force = $true
            }
            New-AzResource @aspParams -ErrorAction Ignore | Out-Null
            $asp = Get-AzAppServicePlan -ResourceGroupName $aspParams.ResourceGroupName -Name $aspParams.ResourceName

            $webParams = @{
                ResourceGroupName = $rg                
                Name = $suffix
                AppServicePlan = $aspParams.ResourceName
                ContainerImageName = "nginx:latest"
                EnableContainerContinuousDeployment = $false
                Location = $location
            }
            New-AzWebApp @webParams -ErrorAction Ignore | Out-Null
            # Workaround: https://github.com/Azure/azure-powershell/issues/10645
            $config = Get-AzResource -ResourceGroupName $rg -ResourceType "Microsoft.Web/sites/config" -ResourceName $suffix -ApiVersion 2018-02-01
            $config.Properties.linuxFxVersion = "DOCKER|nginx:latest"
            $config | Set-AzResource -ApiVersion 2018-02-01 -Force | Out-Null
            $web = Get-AzWebApp -ResourceGroupName $webParams.ResourceGroupName -Name $webParams.Name

            # Lockdown web site
            $config.Properties.ipSecurityRestrictionsDefaultAction = "Deny"
            $config.Properties.scmIpSecurityRestrictionsUseMain = $true
            $config | Set-AzResource -ApiVersion 2018-02-01 -Force | Out-Null
        }

        It "should not have permissions before enabling temporary network access" {
            $resp = Invoke-WebRequest -uri https://$($web.DefaultHostName) -SkipHttpErrorCheck
            $resp.StatusCode | Should -Be 403
        }
        
        It "should connect successfully after enabling temporary network access" {
            Set-TemporaryAzureResourceNetworkAccess -ResourceType WebApp -ResourceGroupName $rg -ResourceName $suffix -Wait
            
            # Pause to ensure the change has taken effect
            Start-Sleep -Seconds 5

            $resp = Invoke-WebRequest -uri https://$($web.DefaultHostName)
            $resp.StatusCode | Should -Be 200
        }
        
        It "should not have permissions after using the 'Revoke' flag" {
            Set-TemporaryAzureResourceNetworkAccess -ResourceType WebApp -ResourceGroupName $rg -ResourceName $suffix -Revoke -Wait

            $resp = Invoke-WebRequest -uri https://$($web.DefaultHostName) -SkipHttpErrorCheck
            $resp.StatusCode | Should -Be 403
        }
    }

    Context "Azure Key Vault" {
        Mock Write-Host {}
    
        BeforeAll {
            # Create key vault
            $kvParams = @{
                ResourceGroupName = $rg
                Name = $suffix
                Sku = "Standard"
                Tag = @{Environment = "Pester"}
                Location = $location
                EnablePurgeProtection = $false
                EnableRbacAuthorization = $true
            }
            New-AzKeyVault @kvParams -ErrorAction Ignore | Out-Null
            $kv = Get-AzKeyVault -ResourceGroupName $kvParams.ResourceGroupName -Name $kvParams.Name
            
            # Ensure the test has the necessary data-plane permissions
            New-AzRoleAssignment -Scope $kv.ResourceId -RoleDefinitionName "Key Vault Secrets Officer" -ObjectId $currentUser.Id -ErrorAction Ignore
            
            # Lockdown access to the storage account
            $kv | Update-AzKeyVaultNetworkRuleSet -DefaultAction Deny -Bypass None

            # Pause to ensure the change has taken effect
            Write-Host "Waiting for key vault firewall to update..."
            Start-Sleep -Seconds 10
        }

        It "should not have permissions before enabling temporary network access" {
            { Get-AzKeyVaultSecret -VaultName $suffix -SecretName "foo" -ErrorAction Stop } |
                Should -Throw "Operation returned an invalid status code 'Forbidden'"
        }
        
        It "should connect successfully after waiting for the temporary network access" {
            Set-TemporaryAzureResourceNetworkAccess -ResourceType KeyVault -ResourceGroupName $rg -ResourceName $suffix
            Start-Sleep -Seconds 5
            Get-AzKeyVaultSecret -VaultName $suffix -SecretName "foo" -ErrorAction Stop |
                Should -Be $null
        }
        
        It "should not have permissions after using the 'Revoke' flag" {
            Set-TemporaryAzureResourceNetworkAccess -ResourceType KeyVault -ResourceGroupName $rg -ResourceName $suffix -Revoke -Wait

            { Get-AzKeyVaultSecret -VaultName $suffix -SecretName "foo" -ErrorAction Stop } |
                Should -Throw "Operation returned an invalid status code 'Forbidden'"
        }
    }
}