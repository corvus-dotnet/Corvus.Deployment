$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".ps1")

. "$here\$sut"

Import-Module Az.Resources

# define other functions that will be mocked
function _EnsureAzureConnection {}
function Get-AzADApplication {}
function Update-AzADApplication { param([string] $ObjectId, [array] $AppRole)}

Describe "Assert-AzureAdAppRole Tests" {

    $mockAppObjectId = "00000000-0000-0000-0000-000000000000"
    $mockAppId = "11111111-1111-1111-1111-111111111111"

    $mockAppRole = @{
        displayName = "Test App Role"
        id = New-Guid | Select-Object -ExpandProperty Guid
        isEnabled = $true
        description = "A Test App Role"
        value = "TestRole"
        allowedMemberType = @("User")
    }

    $commonParams = @{
        AppObjectId = $mockAppObjectId
        AppRoleId = $mockAppRole.id
        DisplayName = $mockAppRole.displayName
        Value = $mockAppRole.value
        AllowedMemberTypes = @("User")
    }

    Context "When no application roles are defined" {

        Mock Write-Host {} -ParameterFilter { $Object.StartsWith("Adding") }
        Mock Update-AzADApplication {} -ParameterFilter { $ObjectId -eq $mockAppObjectId -and $AppRole[0].allowedMemberType -eq $mockAppRole.allowedMemberType }
        Mock Get-AzADApplication {
            @{
                Id = $mockAppObjectId
                AppId = $mockAppId
                AppRole = @()
            }
        }

        $res = Assert-AzureAdAppRole `
                    -Description $mockAppRole.description `
                    @commonParams

        It "should add the new application role" {
            Assert-MockCalled Get-AzADApplication -Times 2
            Assert-MockCalled Update-AzADApplication -Times 1
            Assert-MockCalled Write-Host -Times 1       # asserts the 'add' code path
        }
    }

    Context "When another application role is already defined" {
        Mock Write-Host {} -ParameterFilter { $Object.StartsWith("Adding") }
        Mock Update-AzADApplication {} -ParameterFilter { $ObjectId -eq $mockAppObjectId -and $AppRole[1].allowedMemberType -eq $mockAppRole.allowedMemberType }
        Mock Get-AzADApplication {
            @{
                Id = $mockAppObjectId
                AppId = $mockAppId
                AppRole = @(
                    @{
                        displayName = "Existing App Role"
                        id = New-Guid | Select-Object -ExpandProperty Guid
                        isEnabled = $true
                        description = "An Existing App Role"
                        value = "ExistingAppRole"
                        allowedMemberType = @("Application")
                    }
                )
            }
        }

        $res = Assert-AzureAdAppRole `
                    -Description $mockAppRole.description `
                    @commonParams

        It "should add the new application role" {
            Assert-MockCalled Get-AzADApplication -Times 2
            Assert-MockCalled Update-AzADApplication -Times 1
            Assert-MockCalled Write-Host -Times 1       # asserts the 'add' code path
        }
    } 

    Context "When an existing application role is out-of-date" {

        $updatedDescription = "Modified Test App Role"

        Mock Write-Host {} -ParameterFilter { $Object.StartsWith("Updating") }
        Mock Update-AzADApplication {} -ParameterFilter { $ObjectId -eq $mockAppObjectId -and $AppRole[0].description -eq $updatedDescription }
        Mock Get-AzADApplication {
            @{
                Id = $mockAppObjectId
                AppId = $mockAppId
                AppRole = @($mockAppRole)
            }
        }

        $res = Assert-AzureAdAppRole `
                    -Description $updatedDescription `
                    @commonParams

        It "should update the new application role" {
            Assert-MockCalled Get-AzADApplication -Times 2
            Assert-MockCalled Update-AzADApplication -Times 1
            Assert-MockCalled Write-Host -Times 1       # asserts the 'update' code path
        }
    }

    Context "When an existing application role is up-to-date" {

        Mock Write-Host {} -ParameterFilter { $Object.StartsWith("App role") }
        Mock Update-AzADApplication {} -ParameterFilter { $ObjectId -eq $mockAppObjectId -and $AppRole[0].description -eq $updatedDescription }
        Mock Get-AzADApplication {
            @{
                Id = $mockAppObjectId
                AppId = $mockAppId
                AppRole = @($mockAppRole)
            }
        }

        $res = Assert-AzureAdAppRole `
                    -Description $mockAppRole.description `
                    @commonParams

        It "should update the new application role" {
            Assert-MockCalled Get-AzADApplication -Times 1
            Assert-MockCalled Update-AzADApplication -Times 0
            Assert-MockCalled Write-Host -Times 1       # asserts the 'no change' code path
        }
    }
}