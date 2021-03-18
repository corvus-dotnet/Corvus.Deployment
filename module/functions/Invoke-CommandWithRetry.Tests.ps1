$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".ps1")

. "$here\$sut"

# Ensure this internal function is available for mocking
function _logRetry {}

Describe "Invoke-CommandWithRetry" {
    
    Context "When the command does not error" {
        Mock _logRetry {}
        Mock Write-Host {}

        $result = Invoke-CommandWithRetry { return $true }

        It "should return the output" {
            $result | Should Be $true
        }

        It "should not log a success after retry" {
            Assert-MockCalled _logRetry -Times 0
            Assert-MockCalled Write-Host -Times 0
        }
    }

    Context "When the command does error" {
        Mock _logRetry {}
        Mock Write-Warning {}

        It "should bubble up the exception" {
            { Invoke-CommandWithRetry { throw "force retry" } -RetryDelay 0 } | Should Throw "force retry"
            Assert-MockCalled Write-Warning -Times 1
        }

        It "should retry 5 times by default" {
            Assert-MockCalled _logRetry -Times 5
        }
    }

    Context "When the retry count is overridden" {
        Mock _logRetry {}
        Mock Write-Warning {}

        It "should bubble up the exception" {
            { Invoke-CommandWithRetry { throw "force retry" } -RetryDelay 0 -RetryCount 10 } | Should Throw "force retry"
            Assert-MockCalled Write-Warning -Times 1
        }

        It "should retry the specified amount of times" {
            Assert-MockCalled _logRetry -Times 10
        }
    }

    Context "When the command eventually passes" {
        Mock _logRetry {}
        Mock Write-Warning {}
        Mock Write-Host {}

        $global:failureCount = 0;

        $scriptBlock = {
            $global:failureCount = $global:failureCount + 1
            if ($global:failureCount -eq 3) {
                return $true
            }
            else {
                throw "force retry"
            }
        }

        $result = { Invoke-CommandWithRetry $scriptBlock -RetryDelay 0 -RetryCount 10 }

        It "should not bubble the exception" {
            $result | Should Not Throw
            Assert-MockCalled Write-Warning -Times 0
        }

        It "should log attempting the retries" {
            Assert-MockCalled _logRetry -Times 2
        }

        It "should return the output" {
            $result | Should Be $true
        }

        It "should log a success after retry" {
            Assert-MockCalled Write-Host -Times 1
        }
    }

    Context "When the command accesses outside variables" {
      
        $outsideVariable = "was outside"
        $result = Invoke-CommandWithRetry { return $outsideVariable }

        It "should be able to reference it" {
            $result | Should Be "was outside"
        }
    }
}
