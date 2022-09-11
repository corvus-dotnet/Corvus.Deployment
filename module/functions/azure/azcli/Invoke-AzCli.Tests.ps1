$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".ps1")

. "$here\$sut"

# define other functions that will be mocked
function _EnsureAzureConnection {}

Describe "Invoke-AzCli" {

    Mock _EnsureAzureConnection { $true }

    Context "Command parameter type" {

        # ensure the test isn't polluted by any previous CLI tool that has been run in the current session
        # and that it doesn't fall foul of StrictMode if no tools have been run and $LASTEXITCODE is undefined
        $LASTEXITCODE = 0

        Mock _invokeAzCli {}
        Mock _invokeAzCli {} -ParameterFilter { $CommandLine -eq "az foo bar --query `"[?foo == 'bar']`"" } -Verifiable

        It "should execute a string-based command correctly" {
            $cmd = "foo bar --query `"[?foo == 'bar']`""
            $output,$stdErr = Invoke-AzCli -Command $cmd

            Assert-VerifiableMock
        }

        It "should execute a array-based command correctly" {
            $cmd = @("foo", "bar", "--query `"[?foo == 'bar']`"")
            $output,$stdErr = Invoke-AzCli -Command $cmd
    
            Assert-VerifiableMock
        }
    }

    Context "Error handling" {

        $cmd = "foo bar"

        It "should throw an exception when the command fails" {

            { $output,$stdErr = Invoke-AzCli -Command $cmd -ErrorAction Stop 3>$null } | Should -Throw
        }

        It "should return error messages written to StdOut" {
            $output,$stdErr = Invoke-AzCli -Command $cmd -ExpectedExitCodes @("2") -ErrorAction Stop 3>$null

            $output | Select-Object -First 1 | Should -Match "'foo' is misspelled or not recognized by the system."
        }

        It "should write diagnostic information to the Warning stream" {
            { $output,$stdErr = Invoke-AzCli -Command $cmd -ErrorAction Stop 3>$here/warn-stream.log } | should -Throw
            try {
                Get-Content $here/warn-stream.log | Select-Object -First 1 | Should -Match "azure-cli error diagnostic information:"
            }
            finally {
                Get-Item "$here/warn-stream.log" -ErrorAction SilentlyContinue | Remove-Item
            }
        }
    }
}