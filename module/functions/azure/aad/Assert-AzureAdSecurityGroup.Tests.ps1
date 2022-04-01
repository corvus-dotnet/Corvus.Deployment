$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".ps1")

. "$here\$sut"

# define other functions that will be mocked
function _EnsureAzureConnection {}
function Get-AzADGroup {}
function Invoke-AzRestMethod {}

Describe "Assert-AzureAdSecurityGroup Tests" {

    Mock _EnsureAzureConnection { $true }
    Mock Write-Host {}

    Context "Group does not exist" {

        Mock Get-AzADGroup {}
        Mock _buildUpdateRequest { @{Uri = 'https://fake'} }
        Mock _getGroupOwners {}
        Mock Invoke-AzRestMethod {}

        Context "No default owners" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group'
                OwnersToAssignOnCreation = @()
                StrictMode = $false
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should create the group" {
                Assert-MockCalled _buildUpdateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 1
            }
        }

        Context "Default owners" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group'
                OwnersToAssignOnCreation = @("someone@nowhere.org")
                StrictMode = $false
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should create the group" {
                Assert-MockCalled _buildUpdateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 1
            }
        }
    }

    Context "Group already exists" {

        Mock Get-AzADGroup { return @{
                displayName = 'testgroup'
                id = '00000000-0000-0000-0000-000000000000'
                mailNickname = 'testgroup'
                mailEnabled = $false
                securityEnabled = $true
                description = 'just a test group'
            }
        }
        Mock _buildCreateRequest {}
        Mock _getGroupOwners { @('11111111-1111-1111-1111-111111111111') }
        Mock Invoke-AzRestMethod {}
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
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
        }

        Context "Description updated (StrictMode=false)" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group with a different description'
                OwnersToAssignOnCreation = @()
                StrictMode = $false
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should not update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
        }

        Context "Description updated (StrictMode=true)" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group with a different description'
                OwnersToAssignOnCreation = @()
                StrictMode = $true
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 1
            }
        }

        Context "Default owners - No changes required" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group'
                OwnersToAssignOnCreation = @('11111111-1111-1111-1111-111111111111')
                StrictMode = $false
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should not update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Write-Warning -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
        }

        Context "Default owners - owner missing (StrictMode=false)" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group'
                OwnersToAssignOnCreation = @('22222222-2222-2222-2222-222222222222')
                StrictMode = $false
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should not update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Write-Warning -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
        }

        Context "Default owners - owner missing (StrictMode=true)" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group'
                OwnersToAssignOnCreation = @('22222222-2222-2222-2222-222222222222')
                StrictMode = $true
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should not update the group and warn the owners cannot be updated" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 1
                Assert-MockCalled Write-Warning -Times 1
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
        }

        Context "Backwards-compatible handling of StrictMode" {
            $testGroup = @{
                Name = 'testgroup'
                EmailName = 'testgroup@nowhere.org'
                Description = 'just a test group'
                OwnersToAssignOnCreation = @('22222222-2222-2222-2222-222222222222')
                # Omit the StrictMode parameter to simulate a consumer of an earlier version, before it was added
            }
            Assert-AzureAdSecurityGroup @testGroup

            It "should not update the group and warn the owners cannot be updated" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 1
                Assert-MockCalled Write-Warning -Times 1
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
        }
    }
}