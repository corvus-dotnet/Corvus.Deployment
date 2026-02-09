BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $sut = (Split-Path -Leaf $PSCommandPath).Replace(".Tests.ps1", ".ps1")

    . "$here/$sut"

    # Ensure this internal function is available for mocking
    function _logRetry {}
}

Describe "Invoke-CommandWithRetry" {

    Context "When the command does not error" {
        BeforeAll {
            Mock _logRetry {}
            Mock Write-Host {}

            $result = Invoke-CommandWithRetry { return $true }
        }

        It "should return the output" {
            $result | Should -Be $true
        }

        It "should not log a success after retry" {
            Should -Invoke _logRetry -Times 0 -Scope Context
            Should -Invoke Write-Host -Times 0 -Scope Context
        }
    }

    Context "When the command does error" {
        BeforeAll {
            Mock _logRetry {}
            Mock Write-Warning {}

            $thrownError = $null
            try {
                Invoke-CommandWithRetry { throw "force retry" } -RetryDelay 0
            }
            catch {
                $thrownError = $_
            }
        }

        It "should bubble up the exception" {
            $thrownError | Should -Not -BeNullOrEmpty
            $thrownError.Exception.Message | Should -BeLike "*force retry*"
            Should -Invoke Write-Warning -Times 1 -Scope Context
        }

        It "should retry 5 times by default" {
            Should -Invoke _logRetry -Times 5 -Scope Context
        }
    }

    Context "When the retry count is overridden" {
        BeforeAll {
            Mock _logRetry {}
            Mock Write-Warning {}

            $thrownError = $null
            try {
                Invoke-CommandWithRetry { throw "force retry" } -RetryDelay 0 -RetryCount 10
            }
            catch {
                $thrownError = $_
            }
        }

        It "should bubble up the exception" {
            $thrownError | Should -Not -BeNullOrEmpty
            $thrownError.Exception.Message | Should -BeLike "*force retry*"
            Should -Invoke Write-Warning -Times 1 -Scope Context
        }

        It "should retry the specified amount of times" {
            Should -Invoke _logRetry -Times 10 -Scope Context
        }
    }

    Context "When the command eventually passes" {
        BeforeAll {
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

            $result = Invoke-CommandWithRetry $scriptBlock -RetryDelay 0 -RetryCount 10
        }

        It "should not bubble the exception" {
            { $null } | Should -Not -Throw
            Should -Invoke Write-Warning -Times 0 -Scope Context
        }

        It "should log attempting the retries" {
            Should -Invoke _logRetry -Times 2 -Scope Context
        }

        It "should return the output" {
            $result | Should -Be $true
        }

        It "should log a success after retry" {
            Should -Invoke Write-Host -Times 1 -Scope Context
        }
    }

    Context "When the command accesses outside variables" {
        BeforeAll {
            $outsideVariable = "was outside"
            $result = Invoke-CommandWithRetry { return $outsideVariable }
        }

        It "should be able to reference it" {
            $result | Should -Be "was outside"
        }
    }
}
