# <copyright file="Merge-Hashtables.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Merges the keys from 2 or more hashtables into a single hashtable.

.DESCRIPTION
Merges keys from 2 or more hashtables.

The hashtable provided via the pipeline will be treated with the lowest priority in the event of duplicate key names.

Where multiple hashtables are provided in the arguments, the last specified hashtable will have the highest priority
in the event of duplicate key names.

.INPUTS
Hashtable

.OUTPUTS
Hashtable

.EXAMPLE

@{Foo='bar'} | Merge-Hashtables @{Bar='foo'}

@{Foo='bar'} | Merge-Hashtables @{Bar='foo'} @{FooBar='foobar'; Foo='not-foo'}


#>
function Merge-Hashtables
{
    $output = @{}
    foreach ($hashtable in ($Input + $args)) {
        if ($hashtable -is [Hashtable]) {
            foreach ($key in $hashtable.Keys) {
                $output.$key = $hashtable.$key
            }
        }
    }

    $output
}