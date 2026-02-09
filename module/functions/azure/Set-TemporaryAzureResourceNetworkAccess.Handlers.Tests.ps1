BeforeAll {
    $here = Split-Path -Parent $PSCommandPath

    # Find all the handler implementations
    $handlers = Get-ChildItem "$here/_azureResourceNetworkAccessHandlers/*.ps1"
}

Describe "Handler Validation Tests" {

    Context "<_>" -ForEach @(Get-ChildItem "$(Split-Path -Parent $PSCommandPath)/_azureResourceNetworkAccessHandlers/*.ps1") {

        BeforeAll {
            $handlerName = (Split-Path -LeafBase $_.FullName).TrimStart("_")
            . $_.FullName
        }

        It "should implement the 'addRule' function" {
            Get-Command "_addTempRule_$handlerName" | Should -Not -BeNullOrEmpty
        }
        It "should implement the 'removeRules' function" {
            Get-Command "_removeExistingTempRules_$handlerName" | Should -Not -BeNullOrEmpty
        }
        It "should implement the 'waitForRule' function" {
            Get-Command "_waitForRule_$handlerName" | Should -Not -BeNullOrEmpty
        }
    }
}
