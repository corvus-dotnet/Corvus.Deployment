# <copyright file="Get-UniqueSuffix.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Generates a unique suffix to use for resource names.

.DESCRIPTION
Generates a deterministic hash from a set of inputs, and returns an 12 character alphabetic string to use as a resource name suffix.

.PARAMETER SubscriptionId
The subscription ID of the target Azure subscription.

.PARAMETER StackName
The name of the deployment stack, which is a grouping for what may be multiple services (e.g. a Marain stack).

.PARAMETER ServiceInstance
The instance ID of the service for the deployment.

.PARAMETER Environment
The name of the environment for the deployment.
#>

function Get-UniqueSuffix
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0)]
        [string] $SubscriptionId,

        [Parameter(Position=1)]
        [string] $StackName,

        [Parameter(Position=2)]
        [string] $ServiceInstance,

        [Parameter(Position=3)]
        [string] $Environment
    )

    function Get-UniqueString ([string]$id, $length=12)
    {
        $hashArray = (New-Object System.Security.Cryptography.SHA512Managed).ComputeHash($id.ToCharArray())
        -join ($hashArray[1..$length] | ForEach-Object { [char]($_ % 26 + [byte][char]'a') })
    }

    $inputString = "{0}__{1}__{2}__{3}" -f $SubscriptionId, $StackName, $ServiceInstance, $Environment
    return Get-UniqueString $inputString
}
