# <copyright file="Merge-Hashtables.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe 'Merge-Hashtable tests' {

    $script:h1 = @{ Foo = 'bar' }
    $script:h2 = @{ Bar = 'foo' }
    $script:h3 = @{ FooBar = 'foobar'; Foo = 'notfoo' }

    Context 'Merging 2 hashtables' {

        It 'Returns a merged hashtable' {
            $res = $h1 | Merge-HashTables $h2
            $res.Keys.Count | Should -Be 2
        }
    }

    Context 'Merging 2 hashtables with overlapping keys' {

        It 'Returns a merged hashtable' {
            $res = $h1 | Merge-HashTables $h3
            $res.Keys.Count | Should -Be 2
            $res['Foo'] | Should -Be 'notfoo'
        }
    }

    Context 'Merging 3 hashtables with overlapping keys' {

        It 'Returns a merged hashtable' {
            $res = $h1 | Merge-HashTables $h2 $h3
            $res.Keys.Count | Should -Be 3
            $res['Foo'] | Should -Be 'notfoo'
        }
    }

    Context 'Merging without pipeline input' {
        It 'Returns a merged hashtable' {
            $res = Merge-HashTables $h1 $h2 $h3
            $res.Keys.Count | Should -Be 3
            $res['Foo'] | Should -Be 'notfoo'
        }
    }

    Context 'Merging without pipeline input with array arg' {
        It 'Returns a merged hashtable' {
            $res = Merge-HashTables @($h1,$h2,$h3)
            $res.Keys.Count | Should -Be 3
            $res['Foo'] | Should -Be 'notfoo'
        }
    }
}