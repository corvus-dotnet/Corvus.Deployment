BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $sut = (Split-Path -Leaf $PSCommandPath).Replace(".Tests.ps1", ".ps1")

    . "$here/$sut"

    # import other module functions
    . "$here/Get-AzureAdDirectoryObject.ps1"

    # define other functions that will be mocked
    function _EnsureAzureConnection {}
    function Get-AzADGroup {}
    function Add-AzADGroupMember { param([string[]] $MemberObjectId) }
    function Remove-AzADGroupMember { param([string[]] $MemberObjectId) }
}

Describe "Assert-AzureAdGroupMembership Tests" {

    BeforeAll {
        Mock _EnsureAzureConnection { $true }

        $mockDuplicateGroups = @(
            @{Id="00000000-0000-0000-0000-000000000000"; DisplayName="a-common-group-name"; SecurityEnabled=$true}
            @{Id="11111111-1111-1111-1111-111111111111"; DisplayName="a-common-group-name"; SecurityEnabled=$true}
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
    }

    Context "Group does not exist" {

        BeforeAll {
            Mock Get-AzADGroup {}
            Mock Get-AzureAdDirectoryObject {}
        }

        It "should throw an exception" {
            $mockGroupName = "nonexistent-group"
            { Assert-AzureAdGroupMembership -Name $mockGroupName -RequiredMembers @("user@nowwhere.org") } |
                Should -Throw "The specified group could not be found: DisplayName=$mockGroupName"

            Should -Invoke Get-AzureAdDirectoryObject -Times 0 -Scope Context
        }
    }

    Context "Multiple groups found" {

        BeforeAll {
            Mock Get-AzADGroup { $mockDuplicateGroups }
            Mock Get-AzureAdDirectoryObject {}
        }

        It "should throw an exception" {
            { Assert-AzureAdGroupMembership -Name "a-common-group-name" -RequiredMembers @("user@nowwhere.org") } |
                Should -Throw "Found multiple matching groups: ObjectId=$($mockDuplicateGroups[0].Id); ObjectId=$($mockDuplicateGroups[1].Id);"

            Should -Invoke Get-AzureAdDirectoryObject -Times 0 -Scope Context
        }
    }

    Context "Required members are already in the group (one member)" {

        BeforeAll {
            Mock Get-AzADGroup { $mockGroup }
            Mock _getGroupMembers { $mockGroupMembers[0] }
            Mock Get-AzureAdDirectoryObject { $mockGroupMembers[0] }
            Mock Add-AzADGroupMember {}
            Mock Remove-AzADGroupMember {}

            Assert-AzureAdGroupMembership `
                -Name $mockGroup.DisplayName `
                -RequiredMembers @($mockGroupMembers[0].Id)
        }

        It "should not try to update the group" {
            Should -Invoke Get-AzureAdDirectoryObject -Times 1 -Scope Context
            Should -Invoke Add-AzADGroupMember -Times 0 -Scope Context
            Should -Invoke Remove-AzADGroupMember -Times 0 -Scope Context
        }
    }

    Context "Required members are already in the group (multiple members)" {

        BeforeAll {
            Mock Get-AzADGroup { $mockGroup }
            Mock _getGroupMembers { $mockGroupMembers }
            Mock Get-AzureAdDirectoryObject { $mockGroupMembers[0] } -ParameterFilter { $Criterion -eq $mockGroupMembers[0].Id }
            Mock Get-AzureAdDirectoryObject { $mockGroupMembers[1] } -ParameterFilter { $Criterion -eq $mockGroupMembers[1].Id }
            Mock Add-AzADGroupMember {}
            Mock Remove-AzADGroupMember {}

            Assert-AzureAdGroupMembership `
                -Name $mockGroup.DisplayName `
                -RequiredMembers ($mockGroupMembers | Select-Object -ExpandProperty Id)
        }

        It "should not try to update the group" {
            Should -Invoke Get-AzureAdDirectoryObject -Times 2 -Scope Context
            Should -Invoke Add-AzADGroupMember -Times 0 -Scope Context
            Should -Invoke Remove-AzADGroupMember -Times 0 -Scope Context
        }
    }

    Context "Missing single member" {

        BeforeAll {
            Mock Get-AzADGroup { $mockGroup }
            Mock _getGroupMembers { $mockGroupMembers[0] }
            Mock Get-AzureAdDirectoryObject { $mockGroupMembers[0] } -ParameterFilter { $Criterion -eq $mockGroupMembers[0].Id }
            Mock Get-AzureAdDirectoryObject { $mockGroupMembers[1] } -ParameterFilter { $Criterion -eq $mockGroupMembers[1].Id }
            Mock Add-AzADGroupMember {}
            Mock Remove-AzADGroupMember {}

            Assert-AzureAdGroupMembership `
                -Name $mockGroup.DisplayName `
                -RequiredMembers ($mockGroupMembers | Select-Object -ExpandProperty Id)
        }

        It "should add the missing member to the group" {
            Should -Invoke Get-AzureAdDirectoryObject -Times 2 -Scope Context
            Should -Invoke Add-AzADGroupMember -Times 1 -Scope Context -ParameterFilter { $MemberObjectId -eq $mockGroupMembers[1].Id }
            Should -Invoke Remove-AzADGroupMember -Times 0 -Scope Context
        }
    }

    Context "Missing multiple members" {

        BeforeAll {
            Mock Get-AzADGroup { $mockGroup }
            Mock _getGroupMembers { @() }
            Mock Get-AzureAdDirectoryObject { $mockGroupMembers[0] } -ParameterFilter { $Criterion -eq $mockGroupMembers[0].Id }
            Mock Get-AzureAdDirectoryObject { $mockGroupMembers[1] } -ParameterFilter { $Criterion -eq $mockGroupMembers[1].Id }
            Mock Add-AzADGroupMember {}
            Mock Remove-AzADGroupMember {}

            Assert-AzureAdGroupMembership `
                -Name $mockGroup.DisplayName `
                -RequiredMembers ($mockGroupMembers | Select-Object -ExpandProperty Id)
        }

        It "should add the missing member to the group" {
            Should -Invoke Get-AzureAdDirectoryObject -Times 2 -Scope Context
            Should -Invoke Add-AzADGroupMember -Times 1 -Scope Context -ParameterFilter { $MemberObjectId -eq $mockGroupMembers[0].Id }
            Should -Invoke Add-AzADGroupMember -Times 1 -Scope Context -ParameterFilter { $MemberObjectId -eq $mockGroupMembers[1].Id }
            Should -Invoke Remove-AzADGroupMember -Times 0 -Scope Context
        }
    }

    Context "Additional members are already in the group (Non-Strict)" {

        BeforeAll {
            Mock Get-AzADGroup { $mockGroup }
            Mock _getGroupMembers { $mockGroupMembers }
            Mock Get-AzureAdDirectoryObject { $mockGroupMembers[0] }
            Mock Add-AzADGroupMember {}
            Mock Remove-AzADGroupMember {}

            Assert-AzureAdGroupMembership `
                -Name $mockGroup.DisplayName `
                -RequiredMembers @($mockGroupMembers[0].Id)
        }

        It "should not try to update the group" {
            Should -Invoke Add-AzADGroupMember -Times 0 -Scope Context
            Should -Invoke Remove-AzADGroupMember -Times 0 -Scope Context
        }
    }

    Context "Additional members are already in the group (Strict)" {

        BeforeAll {
            Mock Get-AzADGroup { $mockGroup }
            Mock _getGroupMembers { $mockGroupMembers }
            Mock Get-AzureAdDirectoryObject { $mockGroupMembers[0] }
            Mock Add-AzADGroupMember {}
            Mock Remove-AzADGroupMember {}

            Assert-AzureAdGroupMembership `
                -Name "nonexistent-group" `
                -RequiredMembers @($mockGroupMembers[0].Id) `
                -StrictMode $true
        }

        It "should remove extraneous members" {
            Should -Invoke Add-AzADGroupMember -Times 0 -Scope Context
            Should -Invoke Remove-AzADGroupMember -Times 1 -Scope Context -ParameterFilter { $MemberObjectId -eq $mockGroupMembers[1].Id }
        }
    }

    Context "Adding and removing group members (Strict)" {

        BeforeAll {
            $mockExistingMembers = $mockGroupMembers + @{Id = ([guid]::Empty).Guid.ToString()}
            $requiredMembers = $mockGroupMembers

            Mock Get-AzADGroup { $mockGroup }
            Mock _getGroupMembers { @($mockExistingMembers[0], $mockExistingMembers[2]) }
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
        }

        It "should remove extraneous members" {
            Should -Invoke Get-AzureAdDirectoryObject -Times 1 -Scope Context -ParameterFilter { $Criterion -eq $mockExistingMembers[0].Id }
            Should -Invoke Get-AzureAdDirectoryObject -Times 1 -Scope Context -ParameterFilter { $Criterion -eq $mockExistingMembers[1].Id }
            Should -Invoke Add-AzADGroupMember -Times 1 -Scope Context -ParameterFilter { $MemberObjectId -eq $mockExistingMembers[1].Id }
            Should -Invoke Remove-AzADGroupMember -Times 1 -Scope Context -ParameterFilter { $MemberObjectId -eq $mockExistingMembers[2].Id }
        }
    }

    Context "Adding an invalid member" {
        BeforeAll {
            Mock Get-AzADGroup { $mockGroup }
            Mock _getGroupMembers { @() }
            Mock Get-AzureAdDirectoryObject {} -ParameterFilter { $Criterion -eq [guid]::Empty }
            Mock Add-AzADGroupMember {}
            Mock Remove-AzADGroupMember {}
            Mock Write-Warning {}

            Assert-AzureAdGroupMembership `
                -Name $mockGroup.DisplayName `
                -RequiredMembers @([guid]::Empty)
        }

        It "should not add the member, but log a warning instead" {
            Should -Invoke Get-AzureAdDirectoryObject -Times 1 -Scope Context
            Should -Invoke Add-AzADGroupMember -Times 0 -Scope Context
            Should -Invoke Remove-AzADGroupMember -Times 0 -Scope Context
            Should -Invoke Write-Warning -Times 1 -Scope Context
        }
    }
}
