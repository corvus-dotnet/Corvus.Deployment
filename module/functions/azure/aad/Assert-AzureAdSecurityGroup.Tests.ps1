$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".ps1")

. "$here\$sut"

# define other functions that will be mocked
function _EnsureAzureConnection {}
function Get-AzureAdDirectoryObject { param($Criterion) }
function Get-AzADGroup { param($DisplayName,$ObjectId)}
function Invoke-AzRestMethod { param($Uri,$Payload,$Method) }

Describe "Assert-AzureAdSecurityGroup Tests" {

    Mock _EnsureAzureConnection { $true }
    Mock Write-Host {}

    Context "Group does not exist" {

        $baseMockGroup = @{
            DisplayName = 'testgroup'
            MailNickname = 'testgroup@nowhere.org'
            Description = 'just a test group'
        }
        $mockCreatedGroup = $baseMockGroup.Clone() + @{
            id = (New-Guid).Guid
            mailEnabled = $false
            securityEnabled = $true
        }

        Mock Get-AzADGroup {} -ParameterFilter { $DisplayName }
        Mock Get-AzADGroup { $mockCreatedGroup } -ParameterFilter { $ObjectId }
        Mock _buildUpdateRequest {}
        Mock _getGroupOwners {}
        Mock Invoke-AzRestMethod { @{StatusCode = 200; Content = ($mockCreatedGroup | ConvertTo-Json)} } -ParameterFilter { $Method -eq "POST" -and $Uri.EndsWith("/groups") }

        Context "No group owners specified" {
            $testGroup = $baseMockGroup.Clone() + @{                
                OwnersToAssignOnCreation = @()
                StrictMode = $false
            }
            Mock Get-AzureAdDirectoryObject {}

            $res = Assert-AzureAdSecurityGroup @testGroup

            It "should return the new group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.securityEnabled | Should -Be $true
                Assert-MockCalled Get-AzADGroup -ParameterFilter { $ObjectId -eq $mockCreatedGroup.id } -Times 1
            }
            It "should create the group" {
                Assert-MockCalled _buildUpdateRequest -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 1 `
                    -ParameterFilter {
                        $Method -eq "POST" -and `
                        $Uri -eq "https://graph.microsoft.com/v1.0/groups" -and `
                        $Payload -notmatch "owners"
                    }
            }
        }

        Context "Group owner specified" {
            $testGroup = $baseMockGroup.Clone() + @{
                OwnersToAssignOnCreation = @("someone@nowhere.org")
                StrictMode = $false
            }
            $mockOwners = @( @{ id = [guid]::NewGuid().ToString() } )
            Mock Get-AzureAdDirectoryObject { $mockOwners }

            $res = Assert-AzureAdSecurityGroup @testGroup

            It "should return the new group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.securityEnabled | Should -Be $true
                Assert-MockCalled Get-AzADGroup -ParameterFilter { $ObjectId -eq $mockCreatedGroup.id } -Times 1
            }
            It "should create the group with the specified owner" {
                Assert-MockCalled _buildUpdateRequest -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 1
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 1 `
                    -ParameterFilter { 
                        $Method -eq "POST" -and `
                        $Uri -eq "https://graph.microsoft.com/v1.0/groups" -and `
                        $Payload -match $mockOwners.id
                    }
            }
        }

        Context "Multiple group owners specified" {
            $testGroup = $baseMockGroup.Clone() + @{
                OwnersToAssignOnCreation = @("someone@nowhere.org","MyServicePrincipal")
                StrictMode = $false
            }
            $mockOwnerObjectIds = @(
                @{ id = [guid]::NewGuid().ToString() }
                @{ id = [guid]::NewGuid().ToString() }
            )
            
            Mock Get-AzureAdDirectoryObject { $mockOwnerObjectIds[0] } -ParameterFilter { $Criterion -eq "someone@nowhere.org" }
            Mock Get-AzureAdDirectoryObject { $mockOwnerObjectIds[1] } -ParameterFilter { $Criterion -eq "MyServicePrincipal" }

            $res = Assert-AzureAdSecurityGroup @testGroup

            It "should return the new group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.securityEnabled | Should -Be $true
                Assert-MockCalled Get-AzADGroup -ParameterFilter { $ObjectId -eq $mockCreatedGroup.id } -Times 1
            }
            It "should create the group specifying all the required owners" {
                Assert-MockCalled _buildUpdateRequest -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 2
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 1 `
                    -ParameterFilter {
                        $Method -eq "POST" -and `
                        $Uri -eq "https://graph.microsoft.com/v1.0/groups" -and `
                        $Payload -match $mockOwnerObjectIds[0].id -and `
                        $Payload -match $mockOwnerObjectIds[1].id
                    }
            }
        }

        # Added to catch a previous bug
        Context "Invalid group owners specified - multiple empty string owners" {
            $testGroup = $baseMockGroup.Clone() + @{
                OwnersToAssignOnCreation = @("","")
                StrictMode = $false
            }
            $mockOwnerObjectIds = @( [guid]::NewGuid().ToString(), [guid]::NewGuid().ToString() )
            
            Mock Get-AzureAdDirectoryObject { $mockOwnerObjectIds[0] } -ParameterFilter { $Criterion -eq "someone@nowhere.org" }
            Mock Get-AzureAdDirectoryObject { $mockOwnerObjectIds[1] } -ParameterFilter { $Criterion -eq "MyServicePrincipal" }

            $res = Assert-AzureAdSecurityGroup @testGroup

            It "should return the new group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.securityEnabled | Should -Be $true
                Assert-MockCalled Get-AzADGroup -ParameterFilter { $ObjectId -eq $mockCreatedGroup.id } -Times 1
            }
            It "should create the group with no owners" {
                Assert-MockCalled _buildUpdateRequest -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 1 `
                    -ParameterFilter { `
                        $Method -eq "POST" -and `
                        $Uri -eq "https://graph.microsoft.com/v1.0/groups" -and `
                        $Payload -notmatch 'owners@odata.bind'
                    }
            }
        }
    }
    Context "Group already exists" {

        $groupObjectId = '00000000-0000-0000-0000-000000000000'
        $baseMockGroup = @{
            DisplayName = 'testgroup'
            MailNickname = 'testgroup@nowhere.org'
            Description = 'just a test group'
        }
        $mockExistingGroup = $baseMockGroup.Clone() + @{
            id = $groupObjectId
            mailEnabled = $false
            securityEnabled = $true
        }
        $mockOwners = @( @{ id = [guid]::NewGuid().ToString() } )

        Mock Get-AzADGroup { $mockExistingGroup } -ParameterFilter { $DisplayName }
        Mock _buildCreateRequest {}
        Mock _getGroupOwners { @('11111111-1111-1111-1111-111111111111') }
        Mock Invoke-AzRestMethod { @{StatusCode = 200 } } -ParameterFilter { $Method -eq "PATCH" -and $Uri.EndsWith("/$groupObjectId") }
        Mock Get-AzureAdDirectoryObject { $mockOwners }
        Mock Write-Warning {}

        Context "Up-to-date group with no specified owners" {
            $testGroup = $baseMockGroup.Clone() + @{
                OwnersToAssignOnCreation = @()
                StrictMode = $false
            }
            Mock Get-AzADGroup { $mockExistingGroup } -ParameterFilter { $ObjectId }

            $res = Assert-AzureAdSecurityGroup @testGroup

            It "should return the new group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.Description | Should -Be $testGroup.Description
                Assert-MockCalled Get-AzADGroup -ParameterFilter { $ObjectId } -Times 0
            }
            It "should not update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
        }

        $updatedGroupDesc = 'just a test group with a different description'
        Context "Outdated group with no specified owners (StrictMode=false)" {
            $mockUpdatedGroup = $mockExistingGroup.Clone()
            $mockUpdatedGroup.Description = $updatedGroupDesc
            Mock Get-AzADGroup { $mockUpdatedGroup } -ParameterFilter { $ObjectId }

            $testGroup = $baseMockGroup.Clone()
            $testGroup.Remove("Description")
            $testGroup += @{
                Description = $updatedGroupDesc
                OwnersToAssignOnCreation = @()
                StrictMode = $false
            }

            $res = Assert-AzureAdSecurityGroup @testGroup

            It "should return the existing group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.Description | Should -Be $mockExistingGroup.Description
                Assert-MockCalled Get-AzADGroup -ParameterFilter { $ObjectId } -Times 0
            }
            It "should not update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
        }

        Context "Outdated group with no specified owners (StrictMode=true)" {

            $mockUpdatedGroup = $mockExistingGroup.Clone()
            $mockUpdatedGroup.Description = $updatedGroupDesc
            Mock Get-AzADGroup { $mockUpdatedGroup } -ParameterFilter { $ObjectId }

            $testGroup = $baseMockGroup.Clone()
            $testGroup.Remove("Description")
            $testGroup += @{
                Description = $updatedGroupDesc
                OwnersToAssignOnCreation = @()
                StrictMode = $true
            }
            $res = Assert-AzureAdSecurityGroup @testGroup

            It "should return the updated group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.Description | Should -Be $updatedGroupDesc
                Assert-MockCalled Get-AzADGroup -ParameterFilter { $ObjectId -eq $groupObjectId } -Times 1
            }
            It "should update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 0
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 0
                Assert-MockCalled Invoke-AzRestMethod -Times 1 `
                    -ParameterFilter {
                        $Method -eq "PATCH" -and `
                        $Uri -eq "https://graph.microsoft.com/v1.0/groups/$groupObjectId" -and `
                        $Payload -notmatch "owners" -and $Payload -match $updatedGroupDesc
                    }
            }
        }

        Context "Up-to-date group with additional owner specified" {
            $testGroup = $baseMockGroup.Clone() + @{
                OwnersToAssignOnCreation = @('new-owner@nowhere.com')
                StrictMode = $false
            }
            $res = Assert-AzureAdSecurityGroup @testGroup

            It "should return the existing group" {
                $res.DisplayName | Should -Be $mockExistingGroup.DisplayName
                $res.mailEnabled | Should -Be $mockExistingGroup.mailEnabled
                Assert-MockCalled Get-AzADGroup -ParameterFilter { $ObjectId } -Times 0
            }
            It "should not update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 1
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 1
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
            It "should log a warning that the owners cannot be updated" {
                Assert-MockCalled Write-Warning -Times 1
            }
        }

        Context "Outdated group with additional owner specified (StrictMode=false)" {
            $mockUpdatedGroup = $mockExistingGroup.Clone()
            $mockUpdatedGroup.Description = $updatedGroupDesc
            Mock Get-AzADGroup { $mockUpdatedGroup } -ParameterFilter { $ObjectId }

            $testGroup = $baseMockGroup.Clone()
            $testGroup.Remove("Description")
            $testGroup += @{
                Description = $updatedGroupDesc
                OwnersToAssignOnCreation = @('new-owner@nowhere.com')
                StrictMode = $false
            }
            $res = Assert-AzureAdSecurityGroup @testGroup

            It "should return the existing group" {
                $res.DisplayName | Should -Be $mockExistingGroup.DisplayName
                $res.mailEnabled | Should -Be $mockExistingGroup.mailEnabled
                Assert-MockCalled Get-AzADGroup -ParameterFilter { $ObjectId } -Times 0
            }
            It "should not update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 1
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 1
                Assert-MockCalled Invoke-AzRestMethod -Times 0
            }
            It "should log a warning that the owners cannot be updated" {
                Assert-MockCalled Write-Warning -Times 1
            }
        }

        Context "Outdated group with additional owner specified (StrictMode=true)" {
            $mockUpdatedGroup = $mockExistingGroup.Clone()
            $mockUpdatedGroup.Description = $updatedGroupDesc
            Mock Get-AzADGroup { $mockUpdatedGroup } -ParameterFilter { $ObjectId }

            $testGroup = $baseMockGroup.Clone()
            $testGroup.Remove("Description")
            $testGroup += @{
                Description = $updatedGroupDesc
                OwnersToAssignOnCreation = @('new-owner@nowhere.com')
                StrictMode = $true
            }
            $res = Assert-AzureAdSecurityGroup @testGroup

            It "should return the updated group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.Description | Should -Be $updatedGroupDesc
                Assert-MockCalled Get-AzADGroup -ParameterFilter { $ObjectId -eq $groupObjectId } -Times 1
            }
            It "should update the group" {
                Assert-MockCalled _buildCreateRequest -Times 0
                Assert-MockCalled _getGroupOwners -Times 1
                Assert-MockCalled Get-AzureAdDirectoryObject -Times 1
                Assert-MockCalled Invoke-AzRestMethod -Times 1 `
                    -ParameterFilter {
                        $Method -eq "PATCH" -and `
                        $Uri -eq "https://graph.microsoft.com/v1.0/groups/$groupObjectId" -and `
                        $Payload -notmatch "owners" -and $Payload -match $updatedGroupDesc
                    }
            }
            It "should log a warning that the owners cannot be updated" {
                Assert-MockCalled Write-Warning -Times 1
            }
        }

        Context "Backwards-compatible handling of StrictMode" {
            $testGroup = $baseMockGroup.Clone() + @{
                OwnersToAssignOnCreation = @('MyServicePrincipal')
                # Omit the StrictMode parameter to simulate a consumer of an earlier version, before it was added
            }
            $res = Assert-AzureAdSecurityGroup @testGroup

            It "should return the existing group" {
                $res.DisplayName | Should -Be $mockExistingGroup.DisplayName
                $res.mailEnabled | Should -Be $mockExistingGroup.mailEnabled
                Assert-MockCalled Get-AzADGroup -ParameterFilter { $ObjectId } -Times 0
            }
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