$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".ps1")

. "$here\$sut"

# define other functions that will be mocked
function _EnsureAzureConnection {}

Describe "Assert-AzureAdGroupMembership Tests" {

    Mock _EnsureAzureConnection { $true }

    $mockDuplicateGroups = @(
        @{Id="00000000-0000-0000-0000-000000000000"; DisplayName="fakeGroup1"; SecurityEnabled=$true}
        @{Id="11111111-1111-1111-1111-111111111111"; DisplayName="fakeGroup2"; SecurityEnabled=$true}
    )

    $mockGroup = @{
        Id = "7c408c06-b467-4fd5-96e2-bc9cbc1bd4ee"
        DisplayName = "some-group"
        SecurityEnabled = $true
    }
    $mockGroupMembers = @(
        @{Id = "6cea30de-a493-42b7-9855-2d9a343eca8f"}
        @{Id = "9871e647-e493-4596-84d7-8bbbe8e90447"}
    )

    Context "Group does not exist" {

        Mock Get-AzADGroup {}
        Mock Get-AzureAdDirectoryObject {}

        It "should throw an exception" {
            $mockGroupName = "nonexistent-group"
            { Assert-AzureAdGroupMembership -Name $mockGroupName -RequiredMembers @("user@nowwhere.org") } |
                Should -Throw "The specified group could not be found: DisplayName=$mockGroupName"

            Assert-MockCalled Get-AzureAdDirectoryObject -Times 0
        }
    }

    Context "Multiple groups found" {

        Mock Get-AzADGroup { $mockDuplicateGroups }
        Mock Get-AzureAdDirectoryObject {}

        It "should throw an exception" {
            { Assert-AzureAdGroupMembership -Name "a-common-group-name" -RequiredMembers @("user@nowwhere.org") } | 
                Should -Throw "Found multiple matching groups: ObjectId=$($mockDuplicateGroups[0].Id); ObjectId=$($mockDuplicateGroups[1].Id);"

            Assert-MockCalled Get-AzureAdDirectoryObject -Times 0
        }
    }

    Context "Required members are already in the group (one member)" {

        Mock Get-AzADGroup { $mockGroup }
        Mock Get-AzADGroupMember { $mockGroupMembers[0] }
        Mock Get-AzureAdDirectoryObject { $mockGroupMembers[0] }
        Mock Add-AzADGroupMember {}
        Mock Remove-AzADGroupMember {}

        Assert-AzureAdGroupMembership `
            -Name $mockGroup.DisplayName `
            -RequiredMembers @($mockGroupMembers[0].Id)

        It "should not try to update the group" {
            Assert-MockCalled Get-AzureAdDirectoryObject -Times 1
            Assert-MockCalled Add-AzADGroupMember -Times 0
            Assert-MockCalled Remove-AzADGroupMember -Times 0
        }
    }

    Context "Required members are already in the group (multiple members)" {

        Mock Get-AzADGroup { $mockGroup }
        Mock Get-AzADGroupMember { $mockGroupMembers }
        Mock Get-AzureAdDirectoryObject { $mockGroupMembers[0] } -ParameterFilter { $Criterion -eq $mockGroupMembers[0].Id }
        Mock Get-AzureAdDirectoryObject { $mockGroupMembers[1] } -ParameterFilter { $Criterion -eq $mockGroupMembers[1].Id }
        Mock Add-AzADGroupMember {}
        Mock Remove-AzADGroupMember {}

        Assert-AzureAdGroupMembership `
            -Name $mockGroup.DisplayName `
            -RequiredMembers ($mockGroupMembers | Select-Object -ExpandProperty Id)

        It "should not try to update the group" {
            Assert-MockCalled Get-AzureAdDirectoryObject -Times 2
            Assert-MockCalled Add-AzADGroupMember -Times 0
            Assert-MockCalled Remove-AzADGroupMember -Times 0
        }
    }

    Context "Missing single member" {

        Mock Get-AzADGroup { $mockGroup }
        Mock Get-AzADGroupMember { $mockGroupMembers[0] }
        Mock Get-AzureAdDirectoryObject { $mockGroupMembers[0] } -ParameterFilter { $Criterion -eq $mockGroupMembers[0].Id }
        Mock Get-AzureAdDirectoryObject { $mockGroupMembers[1] } -ParameterFilter { $Criterion -eq $mockGroupMembers[1].Id }
        Mock Add-AzADGroupMember {}
        Mock Remove-AzADGroupMember {}

        Assert-AzureAdGroupMembership `
            -Name $mockGroup.DisplayName `
            -RequiredMembers ($mockGroupMembers | Select-Object -ExpandProperty Id)

        It "should add the missing member to the group" {
            Assert-MockCalled Get-AzureAdDirectoryObject -Times 2
            Assert-MockCalled Add-AzADGroupMember -Times 1 -ParameterFilter { $MemberObjectId -eq $mockGroupMembers[1].Id }
            Assert-MockCalled Remove-AzADGroupMember -Times 0
        }
    }

    Context "Missing multiple members" {

        Mock Get-AzADGroup { $mockGroup }
        Mock Get-AzADGroupMember { @() }
        Mock Get-AzureAdDirectoryObject { $mockGroupMembers[0] } -ParameterFilter { $Criterion -eq $mockGroupMembers[0].Id }
        Mock Get-AzureAdDirectoryObject { $mockGroupMembers[1] } -ParameterFilter { $Criterion -eq $mockGroupMembers[1].Id }
        Mock Add-AzADGroupMember {}
        Mock Remove-AzADGroupMember {}

        Assert-AzureAdGroupMembership `
            -Name $mockGroup.DisplayName `
            -RequiredMembers ($mockGroupMembers | Select-Object -ExpandProperty Id)

        It "should add the missing member to the group" {
            Assert-MockCalled Get-AzureAdDirectoryObject -Times 2
            Assert-MockCalled Add-AzADGroupMember -Times 1 -ParameterFilter { $MemberObjectId -eq $mockGroupMembers[0].Id }
            Assert-MockCalled Add-AzADGroupMember -Times 1 -ParameterFilter { $MemberObjectId -eq $mockGroupMembers[1].Id }
            Assert-MockCalled Remove-AzADGroupMember -Times 0
        }
    }

    Context "Additional members are already in the group (Non-Strict)" {

        Mock Get-AzADGroup { $mockGroup }
        Mock Get-AzADGroupMember { $mockGroupMembers }
        Mock Get-AzureAdDirectoryObject { $mockGroupMembers[0] }
        Mock Add-AzADGroupMember {}
        Mock Remove-AzADGroupMember {}

        Assert-AzureAdGroupMembership `
            -Name $mockGroup.DisplayName `
            -RequiredMembers @($mockGroupMembers[0].Id)

        It "should not try to update the group" {
            Assert-MockCalled Add-AzADGroupMember -Times 0
            Assert-MockCalled Remove-AzADGroupMember -Times 0
        }
    }

    Context "Additional members are already in the group (Strict)" {

        Mock Get-AzADGroup { $mockGroup }
        Mock Get-AzADGroupMember { $mockGroupMembers }
        Mock Get-AzureAdDirectoryObject { $mockGroupMembers[0] }
        Mock Add-AzADGroupMember {}
        Mock Remove-AzADGroupMember {}

        Assert-AzureAdGroupMembership `
            -Name "nonexistent-group" `
            -RequiredMembers @($mockGroupMembers[0].Id) `
            -StrictMode $true

        It "should remove extraneous members" {
            Assert-MockCalled Add-AzADGroupMember -Times 0
            Assert-MockCalled Remove-AzADGroupMember -Times 1 -ParameterFilter { $MemberObjectId -eq $mockGroupMembers[1].Id }
        }
    }

    Context "Adding and removing group members (Strict)" {

        $mockExistingMembers = $mockGroupMembers + @{Id = ([guid]::Empty).Guid.ToString()}
        $requiredMembers = $mockGroupMembers

        Mock Get-AzADGroup { $mockGroup }
        Mock Get-AzADGroupMember { @($mockExistingMembers[0], $mockExistingMembers[2]) }
        Mock Get-AzureAdDirectoryObject { $mockExistingMembers[0] } -ParameterFilter { $Criterion -eq $mockExistingMembers[0].Id }
        Mock Get-AzureAdDirectoryObject { $mockExistingMembers[1] } -ParameterFilter { $Criterion -eq $mockExistingMembers[1].Id }
        Mock Get-AzureAdDirectoryObject { $mockExistingMembers[2] } -ParameterFilter { $Criterion -eq $mockExistingMembers[2].Id }
        # We need to return a group this time, so we still have a group object for the subsequent call Remove-AzADGroupMember
        Mock Add-AzADGroupMember { $mockGroup }
        Mock Remove-AzADGroupMember {}

        Assert-AzureAdGroupMembership `
            -Name $mockGroup.DisplayName `
            -RequiredMembers ($requiredMembers | Select-Object -ExpandProperty Id) `
            -StrictMode $true

        It "should remove extraneous members" {
            Assert-MockCalled Get-AzureAdDirectoryObject -Times 1 -ParameterFilter { $Criterion -eq $mockExistingMembers[0].Id }
            Assert-MockCalled Get-AzureAdDirectoryObject -Times 1 -ParameterFilter { $Criterion -eq $mockExistingMembers[1].Id }
            Assert-MockCalled Add-AzADGroupMember -Times 1 -ParameterFilter { $MemberObjectId -eq $mockExistingMembers[1].Id }
            Assert-MockCalled Remove-AzADGroupMember -Times 1 -ParameterFilter { $MemberObjectId -eq $mockExistingMembers[2].Id }
        }
    }

    Context "Adding an invalid member" {
        Mock Get-AzADGroup { $mockGroup }
        Mock Get-AzADGroupMember { @() }
        Mock Get-AzureAdDirectoryObject {} -ParameterFilter { $Criterion -eq [guid]::Empty }
        Mock Add-AzADGroupMember {}
        Mock Remove-AzADGroupMember {}
        Mock Write-Warning {}

        Assert-AzureAdGroupMembership `
            -Name $mockGroup.DisplayName `
            -RequiredMembers @([guid]::Empty)

        It "should not add the member, but log a warning instead" {
            Assert-MockCalled Get-AzureAdDirectoryObject -Times 1
            Assert-MockCalled Add-AzADGroupMember -Times 0
            Assert-MockCalled Remove-AzADGroupMember -Times 0
            Assert-MockCalled Write-Warning -Times 1
        }
    }
}