$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".ps1")

. "$here\$sut"

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
        allowedMemberTypes = @("User")
    }

    $commonParams = @{
        AppObjectId = $mockAppObjectId
        AppRoleId = $mockAppRole.id
        DisplayName = $mockAppRole.displayName
        Value = $mockAppRole.value
        AllowedMemberTypes = @("User")
    }

    Context "Adding a first application role" {

        Mock Write-Host {} -ParameterFilter { $Object.StartsWith("Adding") }
        Mock Update-AzADApplication {} -ParameterFilter { $ObjectId -eq $mockAppObjectId -and $AppRole[0].allowedMemberTypes -eq $mockAppRole.allowedMemberTypes }
        Mock Get-AzADApplication {
            @{
                Id = $mockAppObjectId
                AppId = $mockAppId
                AppRoles = @()
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

    Context "Adding an additional application role" {
        Mock Write-Host {} -ParameterFilter { $Object.StartsWith("Adding") }
        Mock Update-AzADApplication {} -ParameterFilter { $ObjectId -eq $mockAppObjectId -and $AppRole[1].allowedMemberTypes -eq $mockAppRole.allowedMemberTypes }
        Mock Get-AzADApplication {
            @{
                Id = $mockAppObjectId
                AppId = $mockAppId
                AppRoles = @(
                    @{
                        displayName = "Existing App Role"
                        id = New-Guid | Select-Object -ExpandProperty Guid
                        isEnabled = $true
                        description = "An Existing App Role"
                        value = "ExistingAppRole"
                        allowedMemberTypes = @("Application")
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

    Context "Update an existing application role" {

        $updatedDescription = "Modified Test App Role"

        Mock Write-Host {} -ParameterFilter { $Object.StartsWith("Updating") }
        Mock Update-AzADApplication {} -ParameterFilter { $ObjectId -eq $mockAppObjectId -and $AppRole[0].description -eq $updatedDescription }
        Mock Get-AzADApplication {
            @{
                Id = $mockAppObjectId
                AppId = $mockAppId
                AppRoles = @($mockAppRole)
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
}