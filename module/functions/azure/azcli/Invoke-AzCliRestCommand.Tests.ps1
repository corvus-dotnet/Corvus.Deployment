$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".ps1")

. "$here\$sut"

# Ensure this internal function is available for mocking
function Invoke-AzCli {}

Describe "Invoke-AzCliRestCommand" {

    Context "ParameterSet 'body as hashtable'" {

        # Mock the call and have simply return the requested command so we can validate it in the test
        Mock Invoke-AzCli {
            # return the second argument, which will be the value of the '-Command' parameter
            return $args[1]
        }

        $commonParams = @{
            Uri = "https://foo.com/bar"
            Method = "POST"
        }
        $escapedHeaders = '{\"Content-Type\": \"application/json\"}'

        $expectedResponseFormatString = "rest --uri 'https://foo.com/bar' --method {1} --body '{2}' --headers '{3}'"

        Context "Passing a hashtable" {
            $res = Invoke-AzCliRestCommand @commonParams -Body @{foo="bar"}
            It "should process the request correctly" {
                $expected = $expectedResponseFormatString -f $commonParams.Uri,
                                                             $commonParams.Method,
                                                             '{\"foo\": \"bar\"}',
                                                             $escapedHeaders
                $res | Should Be $expected
            }
        }
        Context "Passing an array of hashtables" {
            $res = Invoke-AzCliRestCommand @commonParams -Body @(@{foo="bar"},@{bar="foo"})
            It "should process the request correctly" {
                $expected = $expectedResponseFormatString -f $commonParams.Uri,
                                                             $commonParams.Method,
                                                             '[{\"foo\": \"bar\"},{\"bar\": \"foo\"}]',
                                                             $escapedHeaders
                $res | Should Be $expected
            }
        }
        Context "Passing a string" {
            It "should throw an expception" {
                { Invoke-AzCliRestCommand @commonParams -Body "foo" } | Should -Throw "The -Body parameter must be of type [hashtable] or [hashtable[]]"
            }
        }
        Context "Passing a string array" {
            It "should throw an expception" {
                { Invoke-AzCliRestCommand @commonParams -Body @("foo","bar") } | Should -Throw "The -Body parameter must be of type [hashtable] or [hashtable[]]"
            }
        }
    }
}
