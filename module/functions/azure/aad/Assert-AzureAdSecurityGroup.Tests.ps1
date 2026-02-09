BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $sut = (Split-Path -Leaf $PSCommandPath).Replace(".Tests.ps1", ".ps1")

    . "$here/$sut"

    # define other functions that will be mocked
    function _EnsureAzureConnection {}
    function Get-AzureAdDirectoryObject { param($Criterion) }
    function Get-AzADGroup { param($DisplayName,$ObjectId)}
    function Invoke-AzRestMethod { param($Uri,$Payload,$Method) }
}

Describe "Assert-AzureAdSecurityGroup Tests" {

    BeforeAll {
        Mock _EnsureAzureConnection { $true }
        Mock Write-Host {}
    }

    Context "Group does not exist" {

        BeforeAll {
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
        }

        Context "No group owners specified" {
            BeforeAll {
                $testGroup = $baseMockGroup.Clone() + @{
                    OwnersToAssignOnCreation = @()
                    StrictMode = $false
                }
                Mock Get-AzureAdDirectoryObject {}

                $res = Assert-AzureAdSecurityGroup @testGroup
            }

            It "should return the new group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.securityEnabled | Should -Be $true
                Should -Invoke Get-AzADGroup -Times 1 -Scope Context `
                    -ParameterFilter { $ObjectId -eq $mockCreatedGroup.id }
            }
            It "should create the group" {
                Should -Invoke _buildUpdateRequest -Times 0 -Scope Context
                Should -Invoke Get-AzureAdDirectoryObject -Times 0 -Scope Context
                Should -Invoke _getGroupOwners -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Context `
                    -ParameterFilter {
                        $Method -eq "POST" -and `
                        $Uri -eq "https://graph.microsoft.com/v1.0/groups" -and `
                        $Payload -notmatch "owners"
                    }
            }
        }

        Context "Group owner specified" {
            BeforeAll {
                $testGroup = $baseMockGroup.Clone() + @{
                    OwnersToAssignOnCreation = @("someone@nowhere.org")
                    StrictMode = $false
                }
                $mockOwners = @( @{ id = [guid]::NewGuid().ToString() } )
                Mock Get-AzureAdDirectoryObject { $mockOwners }

                $res = Assert-AzureAdSecurityGroup @testGroup
            }

            It "should return the new group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.securityEnabled | Should -Be $true
                Should -Invoke Get-AzADGroup -Times 1 -Scope Context `
                    -ParameterFilter { $ObjectId -eq $mockCreatedGroup.id }
            }
            It "should create the group with the specified owner" {
                Should -Invoke _buildUpdateRequest -Times 0 -Scope Context
                Should -Invoke Get-AzureAdDirectoryObject -Times 1 -Scope Context
                Should -Invoke _getGroupOwners -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Context `
                    -ParameterFilter {
                        $Method -eq "POST" -and `
                        $Uri -eq "https://graph.microsoft.com/v1.0/groups" -and `
                        $Payload -match $mockOwners.id
                    }
            }
        }

        Context "Multiple group owners specified" {
            BeforeAll {
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
            }

            It "should return the new group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.securityEnabled | Should -Be $true
                Should -Invoke Get-AzADGroup -Times 1 -Scope Context `
                    -ParameterFilter { $ObjectId -eq $mockCreatedGroup.id }
            }
            It "should create the group specifying all the required owners" {
                Should -Invoke _buildUpdateRequest -Times 0 -Scope Context
                Should -Invoke Get-AzureAdDirectoryObject -Times 2 -Scope Context
                Should -Invoke _getGroupOwners -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Context `
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
            BeforeAll {
                $testGroup = $baseMockGroup.Clone() + @{
                    OwnersToAssignOnCreation = @("","")
                    StrictMode = $false
                }
                $mockOwnerObjectIds = @( [guid]::NewGuid().ToString(), [guid]::NewGuid().ToString() )

                Mock Get-AzureAdDirectoryObject { $mockOwnerObjectIds[0] } -ParameterFilter { $Criterion -eq "someone@nowhere.org" }
                Mock Get-AzureAdDirectoryObject { $mockOwnerObjectIds[1] } -ParameterFilter { $Criterion -eq "MyServicePrincipal" }

                $res = Assert-AzureAdSecurityGroup @testGroup
            }

            It "should return the new group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.securityEnabled | Should -Be $true
                Should -Invoke Get-AzADGroup -Times 1 -Scope Context `
                    -ParameterFilter { $ObjectId -eq $mockCreatedGroup.id }
            }
            It "should create the group with no owners" {
                Should -Invoke _buildUpdateRequest -Times 0 -Scope Context
                Should -Invoke Get-AzureAdDirectoryObject -Times 0 -Scope Context
                Should -Invoke _getGroupOwners -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Context `
                    -ParameterFilter { `
                        $Method -eq "POST" -and `
                        $Uri -eq "https://graph.microsoft.com/v1.0/groups" -and `
                        $Payload -notmatch 'owners@odata.bind'
                    }
            }
        }
    }
    Context "Group already exists" {

        BeforeAll {
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
            $mockExistingOwners = @( @{ id = [guid]::NewGuid().ToString(); displayName = "fake-existing-owner" } )
            $mockOwners = @( @{ id = [guid]::NewGuid().ToString(); displayName = "fake-owner" } )

            Mock Get-AzADGroup { $mockExistingGroup } -ParameterFilter { $DisplayName }
            Mock _buildCreateRequest {}
            # Mock _getGroupOwners { @('') }
            Mock Invoke-AzRestMethod { @{StatusCode = 200; Content = "{ `"value`": [ $($mockExistingOwners | ConvertTo-Json -Compress) ] }" } } -ParameterFilter { $Method -eq "GET" -and $Uri.EndsWith("/owners") }
            Mock Invoke-AzRestMethod { @{StatusCode = 200 } } -ParameterFilter { $Method -eq "PATCH" -and $Uri.EndsWith("/$groupObjectId") }
            Mock Get-AzureAdDirectoryObject { $mockOwners }
            Mock Write-Warning {}

            $updatedGroupDesc = 'just a test group with a different description'
        }

        Context "Up-to-date group with no specified owners" {
            BeforeAll {
                $testGroup = $baseMockGroup.Clone() + @{
                    OwnersToAssignOnCreation = @()
                    StrictMode = $false
                }
                Mock Get-AzADGroup { $mockExistingGroup } -ParameterFilter { $ObjectId }

                $res = Assert-AzureAdSecurityGroup @testGroup
            }

            It "should return the new group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.Description | Should -Be $testGroup.Description
                Should -Invoke Get-AzADGroup -Times 0 -Scope Context -ParameterFilter { $ObjectId }
            }
            It "should not update the group" {
                Should -Invoke _buildCreateRequest -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Context `
                    -ParameterFilter {
                        $Method -eq "GET" -and `
                        $Uri.EndsWith("/owners")
                    }
                Should -Invoke Get-AzureAdDirectoryObject -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Context `
                    -ParameterFilter {
                        $Method -eq "PATCH" -and `
                        $Uri.EndsWith("/$groupObjectId")
                    }
            }
            It "should log no warnings that the owners cannot be updated" {
                Should -Invoke Write-Warning -Times 0 -Scope Context
            }
        }

        Context "Outdated group with no specified owners (StrictMode=false)" {
            BeforeAll {
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
            }

            It "should return the existing group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.Description | Should -Be $mockExistingGroup.Description
                Should -Invoke Get-AzADGroup -Times 0 -Scope Context -ParameterFilter { $ObjectId }
            }
            It "should not update the group" {
                Should -Invoke _buildCreateRequest -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Context -ParameterFilter { $Method -eq "GET" -and $Uri -eq "https://graph.microsoft.com/beta/groups/$groupObjectId/owners" }
                Should -Invoke Get-AzureAdDirectoryObject -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Context -ParameterFilter { $Method -eq "PATCH" -and $Uri -eq "https://graph.microsoft.com/v1.0/groups/$groupObjectId" }
            }
            It "should log no warnings that the owners cannot be updated" {
                Should -Invoke Write-Warning -Times 0 -Scope Context
            }
        }

        Context "Outdated group with no specified owners (StrictMode=true)" {

            BeforeAll {
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
            }

            It "should return the updated group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.Description | Should -Be $updatedGroupDesc
                Should -Invoke Get-AzADGroup -Times 1 -Scope Context -ParameterFilter { $ObjectId -eq $groupObjectId }
            }
            It "should update the group" {
                Should -Invoke _buildCreateRequest -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Context -ParameterFilter { $Method -eq "GET" -and $Uri -eq "https://graph.microsoft.com/beta/groups/$groupObjectId/owners" }
                Should -Invoke Get-AzureAdDirectoryObject -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Context `
                    -ParameterFilter {
                        $Method -eq "PATCH" -and `
                        $Uri -eq "https://graph.microsoft.com/v1.0/groups/$groupObjectId" -and `
                        $Payload -notmatch "owners" -and $Payload -match $updatedGroupDesc
                    }
            }
            It "should log no warnings that the owners cannot be updated" {
                Should -Invoke Write-Warning -Times 0 -Scope Context
            }
        }

        Context "Up-to-date group with up-to-date owners specified" {
            BeforeAll {
                Mock Invoke-AzRestMethod { @{StatusCode = 200; Content = "{ `"value`": [ $($mockExistingOwners | ConvertTo-Json -Compress) ] }" } } -ParameterFilter { $Method -eq "GET" -and $Uri.EndsWith("/owners") }
                Mock Get-AzureAdDirectoryObject { $mockExistingOwners }

                $testGroup = $baseMockGroup.Clone() + @{
                    OwnersToAssignOnCreation = @('fake-existing-owner')
                    StrictMode = $false
                }
                $res = Assert-AzureAdSecurityGroup @testGroup
            }

            It "should return the existing group" {
                $res.DisplayName | Should -Be $mockExistingGroup.DisplayName
                $res.mailEnabled | Should -Be $mockExistingGroup.mailEnabled
                Should -Invoke Get-AzADGroup -Times 0 -Scope Context -ParameterFilter { $ObjectId }
            }
            It "should not update the group" {
                Should -Invoke _buildCreateRequest -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Context -ParameterFilter { $Method -eq "GET" -and $Uri -eq "https://graph.microsoft.com/beta/groups/$groupObjectId/owners" }
                Should -Invoke Get-AzureAdDirectoryObject -Times 1 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Context -ParameterFilter { $Method -eq "PATCH" -and $Uri -eq "https://graph.microsoft.com/v1.0/groups/$groupObjectId" }
            }
            It "should log no warnings that the owners cannot be updated" {
                Should -Invoke Write-Warning -Times 0 -Scope Context
            }
        }

        Context "Up-to-date group with additional owner specified" {
            BeforeAll {
                $testGroup = $baseMockGroup.Clone() + @{
                    OwnersToAssignOnCreation = @('new-owner@nowhere.com')
                    StrictMode = $false
                }
                $res = Assert-AzureAdSecurityGroup @testGroup
            }

            It "should return the existing group" {
                $res.DisplayName | Should -Be $mockExistingGroup.DisplayName
                $res.mailEnabled | Should -Be $mockExistingGroup.mailEnabled
                Should -Invoke Get-AzADGroup -Times 0 -Scope Context -ParameterFilter { $ObjectId }
            }
            It "should not update the group" {
                Should -Invoke _buildCreateRequest -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Context -ParameterFilter { $Method -eq "GET" -and $Uri -eq "https://graph.microsoft.com/beta/groups/$groupObjectId/owners" }
                Should -Invoke Get-AzureAdDirectoryObject -Times 1 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Context -ParameterFilter { $Method -eq "PATCH" -and $Uri -eq "https://graph.microsoft.com/v1.0/groups/$groupObjectId" }
            }
            It "should log a warning that the owners cannot be updated" {
                Should -Invoke Write-Warning -Times 1 -Scope Context
            }
        }

        Context "Outdated group with additional owner specified (StrictMode=false)" {
            BeforeAll {
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
            }

            It "should return the existing group" {
                $res.DisplayName | Should -Be $mockExistingGroup.DisplayName
                $res.mailEnabled | Should -Be $mockExistingGroup.mailEnabled
                Should -Invoke Get-AzADGroup -Times 0 -Scope Context -ParameterFilter { $ObjectId }
            }
            It "should not update the group" {
                Should -Invoke _buildCreateRequest -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Context -ParameterFilter { $Method -eq "GET" -and $Uri -eq "https://graph.microsoft.com/beta/groups/$groupObjectId/owners" }
                Should -Invoke Get-AzureAdDirectoryObject -Times 1 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Context -ParameterFilter { $Method -eq "PATCH" -and $Uri -eq "https://graph.microsoft.com/v1.0/groups/$groupObjectId" }
            }
            It "should log a warning that the owners cannot be updated" {
                Should -Invoke Write-Warning -Times 1 -Scope Context
            }
        }

        Context "Outdated group with additional owner specified (StrictMode=true)" {
            BeforeAll {
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
            }

            It "should return the updated group" {
                $res.DisplayName | Should -Be $testGroup.DisplayName
                $res.Description | Should -Be $updatedGroupDesc
                Should -Invoke Get-AzADGroup -Times 1 -Scope Context -ParameterFilter { $ObjectId -eq $groupObjectId }
            }
            It "should update the group" {
                Should -Invoke _buildCreateRequest -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Context -ParameterFilter { $Method -eq "GET" -and $Uri -eq "https://graph.microsoft.com/beta/groups/$groupObjectId/owners" }
                Should -Invoke Get-AzureAdDirectoryObject -Times 1 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Context `
                    -ParameterFilter {
                        $Method -eq "PATCH" -and `
                        $Uri -eq "https://graph.microsoft.com/v1.0/groups/$groupObjectId" -and `
                        $Payload -notmatch "owners" -and $Payload -match $updatedGroupDesc
                    }
            }
            It "should log a warning that the owners cannot be updated" {
                Should -Invoke Write-Warning -Times 1 -Scope Context
            }
        }

        Context "Backwards-compatible handling of StrictMode" {
            BeforeAll {
                $testGroup = $baseMockGroup.Clone() + @{
                    OwnersToAssignOnCreation = @('MyServicePrincipal')
                    # Omit the StrictMode parameter to simulate a consumer of an earlier version, before it was added
                }
                $res = Assert-AzureAdSecurityGroup @testGroup
            }

            It "should return the existing group" {
                $res.DisplayName | Should -Be $mockExistingGroup.DisplayName
                $res.mailEnabled | Should -Be $mockExistingGroup.mailEnabled
                Should -Invoke Get-AzADGroup -Times 0 -Scope Context -ParameterFilter { $ObjectId }
            }
            It "should not update the group and warn the owners cannot be updated" {
                Should -Invoke _buildCreateRequest -Times 0 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 1 -Scope Context -ParameterFilter { $Method -eq "GET" -and $Uri -eq "https://graph.microsoft.com/beta/groups/$groupObjectId/owners" }
                Should -Invoke Get-AzureAdDirectoryObject -Times 1 -Scope Context
                Should -Invoke Write-Warning -Times 1 -Scope Context
                Should -Invoke Invoke-AzRestMethod -Times 0 -Scope Context -ParameterFilter { $Method -eq "PATCH" -and $Uri -eq "https://graph.microsoft.com/v1.0/groups/$groupObjectId" }
            }
            It "should log a warning that the owners cannot be updated" {
                Should -Invoke Write-Warning -Times 1 -Scope Context
            }
        }
    }
}
