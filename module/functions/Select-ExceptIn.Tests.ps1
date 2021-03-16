# <copyright file="Select-ExceptIn.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

$here = Split-Path -Parent $PSCommandPath
$sut = (Split-Path -Leaf $PSCommandPath) -replace ".Tests"

. "$here\$sut"

Describe "Sekect-ExceptIn Tests" {

    $singleReference = @(
        @{ Name = "foo"; Location = "uk"; Id = "1000" }
    )
    $multiReference = @(
        @{ Name = "foo"; Location = "uk"; Id = "1000" }
        @{ Name = "bar"; Location = "uk"; Id = "1001" }
    )

    Context "ValueFromPipeline" {
        Context "Empty input array" {
            $res = @() | Select-ExceptIn @()

            It "should return no missing items" {
                $res | Should -Be @()
            }
        }

        Context "Empty reference array (single input)" {
            $res = $singleReference | Select-ExceptIn @()

            It "should return a single item array" {
                $res.Count | Should -Be 1
                $res[0] | Should -BeOfType System.Collections.Hashtable
                $res[0].Keys.Count | Should -Be 3
            }
        }

        Context "Empty reference array (multi input)" {
            $res = $multiReference | Select-ExceptIn @()

            It "should return all items" {
                $res.Count | Should -Be 2
                $res[0] | Should -BeOfType System.Collections.Hashtable
                $res[1] | Should -BeOfType System.Collections.Hashtable
                $res[0].Keys.Count | Should -Be 3
                $res[1].Keys.Count | Should -Be 3
            }
        }

        Context "No missing entry" {
            $res = $singleReference | Select-ExceptIn $multiReference

            It "should return no items" {
                $res.Count | Should -Be 0
            }
        }

        Context "No missing entries" {
            $res = $multiReference | Select-ExceptIn $multiReference

            It "should return no items" {
                $res.Count | Should -Be 0
            }
        }

        Context "Missing entry" {
            $res = $multiReference | Select-ExceptIn $singleReference

            It "should return the single missing item" {
                $res.Count | Should -Be 1
                $res[0] | Should -BeOfType System.Collections.Hashtable
                $res[0].Keys.Count | Should -Be 3
            }
        }

        Context "Missing entries" {
            $res = $multiReference | Select-ExceptIn @{ Name = "test"; Location = "uk"; Id = "1002" }

            It "should return all the missing items" {
                $res.Count | Should -Be 2
                $res[0] | Should -BeOfType System.Collections.Hashtable
                $res[1] | Should -BeOfType System.Collections.Hashtable
                $res[0].Keys.Count | Should -Be 3
                $res[1].Keys.Count | Should -Be 3
            }
        }
    }

    Context "ValueFromParameter" {
        Context "Empty input array" {
            $res = Select-ExceptIn -InputObject @() -ReferenceArray @()

            It "should return no missing items" {
                $res | Should -Be @()
            }
        }

        Context "Empty reference array (single input)" {
            $res = Select-ExceptIn -InputObject $singleReference -ReferenceArray @()

            It "should return a single item array" {
                $res.Count | Should -Be 1
                $res[0] | Should -BeOfType System.Collections.Hashtable
                $res[0].Keys.Count | Should -Be 3
            }
        }

        Context "Empty reference array (multi input)" {
            $res = Select-ExceptIn -InputObject $multiReference -ReferenceArray @()

            It "should return all items" {
                $res.Count | Should -Be 2
                $res[0] | Should -BeOfType System.Collections.Hashtable
                $res[1] | Should -BeOfType System.Collections.Hashtable
                $res[0].Keys.Count | Should -Be 3
                $res[1].Keys.Count | Should -Be 3
            }
        }

        Context "No missing entry" {
            $res = Select-ExceptIn -InputObject $singleReference -ReferenceArray $multiReference

            It "should return no items" {
                $res.Count | Should -Be 0
            }
        }

        Context "No missing entries" {
            $res = Select-ExceptIn -InputObject $multiReference -ReferenceArray $multiReference

            It "should return no items" {
                $res.Count | Should -Be 0
            }
        }

        Context "Missing entry" {
            $res = Select-ExceptIn -InputObject $multiReference -ReferenceArray $singleReference

            It "should return the single missing item" {
                $res.Count | Should -Be 1
                $res[0] | Should -BeOfType System.Collections.Hashtable
                $res[0].Keys.Count | Should -Be 3
            }
        }

        Context "Missing entries" {
            $res = Select-ExceptIn -InputObject $multiReference -ReferenceArray @{ Name = "test"; Location = "uk"; Id = "1002" }

            It "should return all the missing items" {
                $res.Count | Should -Be 2
                $res[0] | Should -BeOfType System.Collections.Hashtable
                $res[1] | Should -BeOfType System.Collections.Hashtable
                $res[0].Keys.Count | Should -Be 3
                $res[1].Keys.Count | Should -Be 3
            }
        }
    }
}