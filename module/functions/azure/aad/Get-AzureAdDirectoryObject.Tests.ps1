$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".ps1")

. "$here\$sut"

# define other functions that will be mocked
function _EnsureAzureConnection {}

Describe "Get-AzureAdDirectoryObject Tests" {

    function _EnsureAzureConnection { $true }

    # Setup some mock AzureAD objects
    $mockGroup = @{
        ObjectId = '5c21a713-c12c-4592-807e-e45b1adc8634'
        DisplayName = 'Mock Group'
    }
    $mockServicePrincipal = @{
        ObjectId = '308d6796-5639-49da-a0b4-17e37de6e4de'
        ApplicationId = 'c6c60257-7088-41b0-a8b3-6cdfe22c4855'
        DisplayName = 'Mock Service Principal'
    }
    $mockUser = @{
        ObjectId = '5f3c6343-88e8-4888-afcd-2a7acfaa7fc7'
        DisplayName = 'Mock User'
        UserPrincipalName = 'mock.user@nowhere.org'
    }

    # Mock out the calls to AzureAD, intercepting those that need to simulate a matching result
    Mock _groupById { $global:methodUsed="ObjectId"; $mockGroup } -ParameterFilter { $ObjectId -eq $mockGroup.ObjectId }
    Mock _groupById {}
    Mock _groupByName { $global:methodUsed="DisplayName"; $mockGroup } -ParameterFilter { $DisplayName -eq $mockGroup.DisplayName }
    Mock _groupByName {}
    Mock _spByAppId { $global:methodUsed="ApplicationId"; $mockServicePrincipal } -ParameterFilter { $ApplicationId -eq $mockServicePrincipal.ApplicationId }
    Mock _spByAppId {}
    Mock _spByObjectId { $global:methodUsed="ObjectId"; $mockServicePrincipal } -ParameterFilter { $ObjectId -eq $mockServicePrincipal.ObjectId }
    Mock _spByObjectId {}
    Mock _spByName { $global:methodUsed="DisplayName"; $mockServicePrincipal } -ParameterFilter { $DisplayName -eq $mockServicePrincipal.DisplayName }
    Mock _spByName {}
    Mock _userById { $global:methodUsed="ObjectId"; $mockUser } -ParameterFilter { $ObjectId -eq $mockUser.ObjectId }
    Mock _userById {}
    Mock _userByName { $global:methodUsed="DisplayName"; $mockUser } -ParameterFilter { $DisplayName -eq $mockUser.DisplayName }
    Mock _userByName {}
    Mock _userByUpn { $global:methodUsed="UserPrincipalName"; $mockUser } -ParameterFilter { $UserPrincipalName -eq $mockUser.UserPrincipalName }
    Mock _userByUpn {}

    Mock Write-Verbose {}
    Mock Write-Warning {}

    Context "Finding a group" {

        Context "Searching by ObjectId" {
            $global:methodUsed = $null
            $res = Get-AzureAdDirectoryObject -Criterion $mockGroup.ObjectId
            
            It "should return the group" {
                $methodUsed | Should -Be "ObjectId"
                $res.DisplayName | Should -Be $mockGroup.DisplayName
                
                Assert-MockCalled _groupById -Times 1
                Assert-MockCalled _spByAppId -Times 1
                Assert-MockCalled _spByObjectId -Times 1
                Assert-MockCalled _userById -Times 1
                Assert-MockCalled _groupByName -Times 0
                Assert-MockCalled _spByName -Times 0
                Assert-MockCalled _userByName -Times 0
            }
        }

        Context "Searching by DisplayName" {
            $global:methodUsed = $null
            $res = Get-AzureAdDirectoryObject -Criterion $mockGroup.DisplayName
            
            It "should return the group" {
                $methodUsed | Should -Be "DisplayName"
                $res.ObjectId | Should -Be $mockGroup.ObjectId
                
                Assert-MockCalled _groupById -Times 0
                Assert-MockCalled _spByAppId -Times 0
                Assert-MockCalled _spByObjectId -Times 0
                Assert-MockCalled _userById -Times 0
                Assert-MockCalled _groupByName -Times 1
                Assert-MockCalled _spByName -Times 1
                Assert-MockCalled _userByName -Times 1
            }
        }
    }

    Context "Finding a service principal" {

        Context "Searching by ObjectId" {
            $global:methodUsed = $null
            $res = Get-AzureAdDirectoryObject -Criterion $mockServicePrincipal.ObjectId
            
            It "should return the service principal" {
                $methodUsed | Should -Be "ObjectId"
                $res.DisplayName | Should -Be $mockServicePrincipal.DisplayName
                
                Assert-MockCalled _groupById -Times 1
                Assert-MockCalled _spByAppId -Times 1
                Assert-MockCalled _spByObjectId -Times 1
                Assert-MockCalled _userById -Times 1
                Assert-MockCalled _groupByName -Times 0
                Assert-MockCalled _spByName -Times 0
                Assert-MockCalled _userByName -Times 0
            }
        }

        Context "Searching by ApplicationId" {
            $global:methodUsed = $null
            $res = Get-AzureAdDirectoryObject -Criterion $mockServicePrincipal.ApplicationId
            
            It "should return the service principal" {
                $methodUsed | Should -Be "ApplicationId"
                $res.DisplayName | Should -Be $mockServicePrincipal.DisplayName
                
                Assert-MockCalled _groupById -Times 1
                Assert-MockCalled _spByAppId -Times 1
                Assert-MockCalled _spByObjectId -Times 1
                Assert-MockCalled _userById -Times 1
                Assert-MockCalled _groupByName -Times 0
                Assert-MockCalled _spByName -Times 0
                Assert-MockCalled _userByName -Times 0
            }
        }

        Context "Searching by DisplayName" {
            $global:methodUsed = $null
            $res = Get-AzureAdDirectoryObject -Criterion $mockServicePrincipal.DisplayName
            
            It "should return the service principal" {
                $methodUsed | Should -Be "DisplayName"
                $res.ObjectId | Should -Be $mockServicePrincipal.ObjectId
                
                Assert-MockCalled _groupById -Times 0
                Assert-MockCalled _spByAppId -Times 0
                Assert-MockCalled _spByObjectId -Times 0
                Assert-MockCalled _userById -Times 0
                Assert-MockCalled _groupByName -Times 1
                Assert-MockCalled _spByName -Times 1
                Assert-MockCalled _userByName -Times 1
            }
        }
    }

    Context "Finding a user" {

        Context "Searching by ObjectId" {
            $global:methodUsed = $null
            $res = Get-AzureAdDirectoryObject -Criterion $mockUser.ObjectId
            
            It "should return the user" {
                $methodUsed | Should -Be "ObjectId"
                $res.DisplayName | Should -Be $mockUser.DisplayName
                
                Assert-MockCalled _groupById -Times 1
                Assert-MockCalled _spByAppId -Times 1
                Assert-MockCalled _spByObjectId -Times 1
                Assert-MockCalled _userById -Times 1
                Assert-MockCalled _groupByName -Times 0
                Assert-MockCalled _spByName -Times 0
                Assert-MockCalled _userByName -Times 0
            }
        }

        Context "Searching by DisplayName" {
            $global:methodUsed = $null
            $res = Get-AzureAdDirectoryObject -Criterion $mockUser.DisplayName
            
            It "should return the user" {
                $methodUsed | Should -Be "DisplayName"
                $res.ObjectId | Should -Be $mockUser.ObjectId
                
                Assert-MockCalled _groupById -Times 0
                Assert-MockCalled _spByAppId -Times 0
                Assert-MockCalled _spByObjectId -Times 0
                Assert-MockCalled _userById -Times 0
                Assert-MockCalled _groupByName -Times 1
                Assert-MockCalled _spByName -Times 1
                Assert-MockCalled _userByName -Times 1
            }
        }

        Context "Searching by UPN" {
            $global:methodUsed = $null
            $res = Get-AzureAdDirectoryObject -Criterion $mockUser.UserPrincipalName
            
            It "should return the user" {
                $methodUsed | Should -Be "UserPrincipalName"
                $res.ObjectId | Should -Be $mockUser.ObjectId
                
                Assert-MockCalled _groupById -Times 0
                Assert-MockCalled _spByAppId -Times 0
                Assert-MockCalled _spByObjectId -Times 0
                Assert-MockCalled _userById -Times 0
                Assert-MockCalled _groupByName -Times 1
                Assert-MockCalled _spByName -Times 1
                Assert-MockCalled _userByName -Times 1
            }
        }
    }
}