$here = Split-Path -Parent $MyInvocation.MyCommand.Path

# Find all the handler implementations
$handlers = Get-ChildItem "$here\_azureResourceNetworkAccessHandlers\*.ps1"

Describe "Handler Validation Tests" {

    foreach ($handler in $handlers) {

        $handlerName = (Split-Path -LeafBase $handler.FullName).TrimStart("_")

        Context $handlerName {

            . $handler.FullName

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
}