# <copyright file="Assert-AzureAdGroupMembership.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Searches the different types of AzureAD directory objects to find a match for the specified criterion.

.DESCRIPTION
Searches for groups, service principals and users in AzureAD that match the specified criteria.

.PARAMETER Criterion
When a GUID, will be compared with the ApplicationId and/or ObjectId properties of the relevant AzureAD directory objects. Non-GUID values will
be queried as exact matches against the 'DisplayName' property.

.PARAMETER Single
When true, an exception will be thrown if multiple matches are found.

.PARAMETER SuppressMultipleMatchWarning
When true, no warnings will be logged if multiple matches are found.

#>

function Get-AzureAdDirectoryObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Criterion,

        [switch] $Single,

        [switch] $SuppressMultipleMatchWarning
    )

    # Check whether we have a valid AzPowerShell connection, but no subscription-level access is required
    _EnsureAzureConnection -AzPowerShell -TenantOnly -ErrorAction Stop | Out-Null

    # These are the methods that run the AzureAD queries based on GUID based criteria
    [scriptblock[]]$lookupMethodsById = @(
        { _groupById -ObjectId $args[0] }
        { _spByAppId -ApplicationId $args[0] }
        { _spByObjectId -ObjectId $args[0] }
        { _userById -ObjectId $args[0] }
    )
    # These are the methods that run the AzureAD queries based on non-GUID based criteria
    [scriptblock[]]$lookupMethodsByName = @(
        { _groupByName -DisplayName $args[0] }
        { _spByName -DisplayName $args[0] }
        { _userByName -DisplayName $args[0] }
        { _userByUpn -UserPrincipalName $args[0] }
    )

    $matchesFound = @()
    try {
        # Attempt queries by ObjectId/ApplicationId - if the Criteria isn't a GUID then this block will be skipped due to the casting exception
        $memberGuid = [guid]$Criterion
        foreach ($lookupMethod in $lookupMethodsById) {
            try {
                $directoryObject = Invoke-Command $lookupMethod -ArgumentList @($memberGuid)
                if ($directoryObject) {
                    $matchesFound += $directoryObject
                }
            }
            catch {}
        }
    }
    catch {
        # Atrtempt queries by DisplayName/UPN
        foreach ($lookupMethod in $lookupMethodsByName) {
            try {
                $directoryObject = Invoke-Command $lookupMethod -ArgumentList @($Criterion)
                if ($directoryObject) {
                    $matchesFound += $directoryObject
                }
            }
            catch {}
        }
    }

    # Parse any matching results
    if ($matchesFound.Count -gt 1) {
        $multiMatchOutput = $matchesFound | ForEach-Object {
            "`t{0}`t{1}`t{2}`n" -f `
                $_.GetType().Name,
                $_.DisplayName,
                $_.Id
        }
        if (!$SuppressMultipleMatchWarning) {
            Write-Warning "Found multiple matching directory objects, when expecting a single result:`n$multiMatchOutput"
        }

        if ($Single) {
            throw "Found multiple matching directory objects when expecting a single results - check previous log messages for details"
        }
    }
    
    return $matchesFound
}

#
# These functions handle the underlying AzureAD queries and allow us to mock-out the
# AzureAD connectivity in our tests
#
function _groupById {
    param($ObjectId)
    # Look-ups via ObjectId will error when no matches are found
    $res = Get-AzAdGroup -ObjectId $ObjectId -ErrorAction Stop
    Write-Verbose "Found Group by ObjectId"
    $res
}
function _spByAppId {
    param($ApplicationId)
    # Look-ups via ApplicationId return null when no matches are found
    $res = Get-AzADServicePrincipal -ApplicationId $ApplicationId -ErrorAction Stop
    if ($res) {
        Write-Verbose "Found Service Principal by ApplicationId"
    }
    $res
}
function _spByObjectId {
    param($ObjectId)
    # Look-ups via ObjectId will error when no matches are found
    $res = Get-AzADServicePrincipal -ObjectId $ObjectId -ErrorAction Stop
    Write-Verbose "Found Service Principal by ObjectId"
    $res
}
function _userById {
    param($ObjectId)
    # Look-ups via ObjectId will error when no matches are found
    $res = Get-AzAdUser -ObjectId $ObjectId -ErrorAction Stop
    Write-Verbose "Found User by ObjectId"
    $res
}

function _groupByName {
    param($DisplayName)
    # Look-ups via DisplayName return null when no matches are found
    $res = Get-AzAdGroup -DisplayName $DisplayName -ErrorAction Stop
    if ($res) {
        Write-Verbose "Found Group by Name"
    }
    $res
}
function _spByName {
    param($DisplayName)
    # Look-ups via DisplayName return null when no matches are found
    $res = Get-AzADServicePrincipal -DisplayName $DisplayName -ErrorAction Stop
    if ($res) {
        Write-Verbose "Found Service Principal by Name"
    }
    $res
}
function _userByName {
    param($DisplayName)
    # Look-ups via DisplayName return null when no matches are found
    $res = Get-AzAdUser -DisplayName $DisplayName -ErrorAction Stop
    if ($res) {
        Write-Verbose "Found User by Name"
    }
    $res
}
function _userByUpn {
    param($UserPrincipalName)
    # Look-ups via UserPrincipalName return null when no matches are found
    $res = $null
    if ($UserPrincipalName -match "@") {
        $res = Get-AzAdUser -UserPrincipalName $UserPrincipalName -ErrorAction Stop
        if ($res) {
            Write-Verbose "Found User by UserPrincipalName"
        }
    }
    $res
} 
