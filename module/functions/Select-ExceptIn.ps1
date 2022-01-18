# <copyright file="Select-ExceptIn.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Compares two Hashtable arrays and returns the hashtable entries from the input that don't exist in the reference array.

.DESCRIPTION
This is intended to find hashtable-based objects that are missing from the reference array of hashtables.  For
example, as part of some synchronisation logic.

NOTE: This function does not support nested hashtables as it relies on Compare-Object for the comparison of
each hashtable key.

.NOTES
This function's primary use-case is to support determining how a 'desired state' differs from a 'current state'.

For example, comparing the current Azure resource manager permissions with those defined in configuration.

In this case the the raw objects cannot be compared as they have different properties - the current state will be
available as the 'Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleAssignment' type, whilst the configuration
may defined with a much simpler hashtable structure.

Therefore the usage of this function assumes that custom projections will be created that map the current and
desired states into a common structure and it is those projections that get passed to this function.  It is then
the responsibility of the consumer to interpret the results for their particular scenario.

.PARAMETER InputObject
The array of hashtables that should exist in the reference array.

.PARAMETER ReferenceArray
The array of hashtables to be compared with the input array.

.OUTPUTS
An array of hashtables representing the input hashtables that do not exist in the reference array.

.EXAMPLE
$input = @(
    @{ Name="foo"; Id=1 }
    @{ Name="foobar"; Id=3 }
)
$reference = @(
    @{ Name="bar"; Id=100 }
    @{ Name="foobar"; Id=3 }
)

$input | Select-ExceptIn $reference

The output would be:
@(
    @{ Name="foo"; Id=1 }
)

#>

function Select-ExceptIn
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyCollection()]
        [Hashtable[]] $InputObject,

        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyCollection()]
        [Hashtable[]] $ReferenceArray
	)

    Begin {
        $results = @()
    }

    Process {
        foreach ($inputItem in $InputObject) {
            $inputItemToCompare = _sortedHashtable($inputItem)

            # Assume the item is missing unless we find a match
            $isMissing = $true
            foreach ($referenceItem in $ReferenceArray) {
                $refItemToCompare = _sortedHashtable($referenceItem)

                $keysDiff = Compare-Object $refItemToCompare.Keys $inputItemToCompare.Keys
                $valuesDiff = Compare-Object $refItemToCompare.Values $inputItemToCompare.Values
                if (!$keysDiff -and !$valuesDiff) {
                    # When the comparisons return null then we have found a hashtable in the
                    # reference array that exactly matches the input item currently being
                    # processed.
                    
                    # Record that it is not missing and abandon this inner loop
                    $isMissing = $false
                    break
                }
            }

            if ($isMissing) {
                $results += $inputItem
            }
        }
    }

    End {
        @(,$results)
    }
}

function _sortedHashtable
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable] $Hashtable
    )

    $sortedHashtable = [ordered]@{}
    $Hashtable.Keys | Sort-Object | ForEach-Object {
        $sortedHashtable.Add($_, $Hashtable[$_])
    }

    $sortedHashtable
}