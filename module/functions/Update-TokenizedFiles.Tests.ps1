# <copyright file="Update-TokenizedFiles.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

$here = Split-Path -Parent $PSCommandPath
$sut = (Split-Path -Leaf $PSCommandPath) -replace ".Tests"

. "$here\$sut"

$defaultTokenRegexPattern = "\#\{.*\}\#"

Describe "Update-TokenizedFiles Tests" {

    Context "Single File: Using the default TokenRegexPattern" {
        $testJsonConfig = @"
{
    "settingA": "#{SETTING_A}#",
    "settingB": "B"
}    
"@
        $testJsonFile = "TestDrive:/test-config.json"
        Set-Content -Path $testJsonFile -Value $testJsonConfig

        $tokenValues = @{
            SETTING_A = "foo"
            SETTING_B = "bar"
        }

        It "should start with a tokenised file" {
            (Get-Content -Raw -Path $testJsonFile) -match $defaultTokenRegexPattern | Should -Be $true
        }

        Update-TokenizedFiles -FilesToProcess @($testJsonFile) `
                              -TokenValuePairs $tokenValues

        It "should replace the required token" {
            (Get-Content -Raw -Path $testJsonFile) -match $defaultTokenRegexPattern | Should -Be $false
        }

        It "should replace the required token with the correct value" {
            (Get-Content -Raw -Path $testJsonFile | ConvertFrom-Json).settingA | Should -Be "foo"
        }

    }
}