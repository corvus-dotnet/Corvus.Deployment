$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".ps1")

. "$here\$sut"

# define other functions that will be mocked
function _EnsureAzureConnection {}
function Get-AzureAdDirectoryObject { param($Criterion) }
function Get-AzADGroup {}
function Invoke-AzRestMethod { param($Uri,$Payload) }

Describe "Assert-AzureAdSecurityGroup Tests" {

    Mock _EnsureAzureConnection { $true }
    Mock Write-Host {}

    Context "Group does not exist" {

        Mock Get-AzADGroup {}
        Mock _buildUpdateRequest { @{Uri = 'https://fake'} }
        Mock _getGroupOwners {}
        Mock Invoke-AzRestMethod {}

        Context "No default owners specified" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group'
                OwnersToAssignOnCreation = @()
                StrictMode = $false
            }
            Mock Get-AzureAdDirectoryObject {}

            Assert-AzureAdSecurityGroup @testGroup

            It "should create the group" {
                Assert-MockCalled _buildUpdateRequest -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 1 -ParameterFilter { $Uri -eq "https://graph.microsoft.com/v1.0/groups" -and $Payload -notmatch "owners" }
            }
        }

        Context "Default owner specified" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group'
                OwnersToAssignOnCreation = @("someone@nowhere.org")
                StrictMode = $false
            }
            $mockOwnerObjectId = [guid]::NewGuid().ToString()
            Mock Get-AzureAdDirectoryObject { $mockOwnerObjectId }

            Assert-AzureAdSecurityGroup @testGroup

            It "should create the group with the specified owner" {
                Assert-MockCalled _buildUpdateRequest -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 1
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 1 -ParameterFilter { $Uri -eq "https://graph.microsoft.com/v1.0/groups" -and $Payload -match $mockOwnerObjectId }
            }
        }

        Context "Multiple default owners specified" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group'
                OwnersToAssignOnCreation = @("someone@nowhere.org","MyServicePrincipal")
                StrictMode = $false
            }
            $mockOwnerObjectIds = @( [guid]::NewGuid().ToString(), [guid]::NewGuid().ToString() )
            
            Mock Get-AzureAdDirectoryObject { $mockOwnerObjectIds[0] } -ParameterFilter { $Criterion -eq "someone@nowhere.org" }
            Mock Get-AzureAdDirectoryObject { $mockOwnerObjectIds[1] } -ParameterFilter { $Criterion -eq "MyServicePrincipal" }

            Assert-AzureAdSecurityGroup @testGroup

            It "should create the group specifying all the required owners" {
                Assert-MockCalled _buildUpdateRequest -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 2
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 1 `
                    -ParameterFilter { `
                        $Uri -eq "https://graph.microsoft.com/v1.0/groups" -and `
                        $Payload -match $mockOwnerObjectIds[0] -and `
                        $Payload -match $mockOwnerObjectIds[1]
                    }
            }
        }
    }

    Context "Group already exists" {

        $groupObjectId = '00000000-0000-0000-0000-000000000000'
        Mock Get-AzADGroup { return @{
                displayName = 'testgroup'
                id = $groupObjectId
                mailNickname = 'testgroup'
                mailEnabled = $false
                securityEnabled = $true
                description = 'just a test group'
            }
        }
        Mock _buildCreateRequest {}
        Mock _getGroupOwners { @('11111111-1111-1111-1111-111111111111') }
        Mock Invoke-AzRestMethod {}
        $mockOwnerObjectId = [guid]::NewGuid().ToString()
        Mock Get-AzureAdDirectoryObject { $mockOwnerObjectId }
        Mock Write-Warning {}

        Context "No default owners - No changes required" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group'
                OwnersToAssignOnCreation = @()
                StrictMode = $false
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should not update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
        }

        $updatedGroupDesc = 'just a test group with a different description'
        Context "Description updated (StrictMode=false)" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = $updatedGroupDesc
                OwnersToAssignOnCreation = @()
                StrictMode = $false
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should not update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
        }

        Context "Description updated (StrictMode=true)" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = $updatedGroupDesc
                OwnersToAssignOnCreation = @()
                StrictMode = $true
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 1 `
                    -ParameterFilter {  
                        $Uri -eq "https://graph.microsoft.com/v1.0/groups/$groupObjectId" -and  
                        $Payload -notmatch "owners" -and $Payload -match $updatedGroupDesc
                    }
            }
        }

        Context "Default owners - No changes required" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group'
                OwnersToAssignOnCreation = @('anothergroup@nowhere.com')
                StrictMode = $false
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should not update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 1
                Assert-MockCalled Write-Warning -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
        }

        Context "Default owners - owner missing (StrictMode=false)" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group'
                OwnersToAssignOnCreation = @('someone@nowhere.org')
                StrictMode = $false
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should not update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 1
                Assert-MockCalled Write-Warning -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
        }

        Context "Default owners - owner missing (StrictMode=true)" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group'
                OwnersToAssignOnCreation = @('someone@nowhere.org')
                StrictMode = $true
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should not update the group and warn the owners cannot be updated" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 1
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 1
                Assert-MockCalled Write-Warning -Times 1
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
        }

        Context "Backwards-compatible handling of StrictMode" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group'
                OwnersToAssignOnCreation = @('MyServicePrincipal')
                # Omit the StrictMode parameter to simulate a consumer of an earlier version, before it was added
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should not update the group and warn the owners cannot be updated" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 1
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 1
                Assert-MockCalled Write-Warning -Times 1
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
        }
    }
}