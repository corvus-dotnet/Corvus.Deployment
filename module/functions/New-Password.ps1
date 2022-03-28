# <copyright file="New-Password.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Returns a random password containing alpha-numerics and symbols.

.DESCRIPTION
Returns a cryptographically secure random-generated password containing upper-case, lower-case, numeric and symbol characters.

.PARAMETER Length
The length of the password to be generated.

.PARAMETER ValidSymbols
A character array containing the characters that will be treated as symbols when validating the password strength.

.OUTPUTS
SecureString

.EXAMPLE

$pwd = New-Password
$pwd = New-Password -Length 18

#>
function New-Password
{
    [CmdletBinding()]
    param
    (
        [ValidateRange(12, 256)]
        [int] $Length = 16,

        [ValidateNotNull()]
        [char[]] $ValidSymbols = '!@#$%^&*'.ToCharArray()
    )

    # reference: https://gist.github.com/onlyann/00d9bb09d4b1338ffc88a213509a6caf
    $characterList = 'a'..'z' + 'A'..'Z' + '0'..'9' + $ValidSymbols
    
    $iterations = 0
    do {
        $password = ""
        for ($i = 0; $i -lt $length; $i++) {
            $randomIndex = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(0, $characterList.Length)
            $password += $characterList[$randomIndex]
        }

        [int]$hasLowerChar = $password -cmatch '[a-z]'
        [int]$hasUpperChar = $password -cmatch '[A-Z]'
        [int]$hasDigit = $password -match '[0-9]'
        [int]$hasSymbol = $password.IndexOfAny($ValidSymbols) -ne -1

        $iterations++
    }
    until (($hasLowerChar + $hasUpperChar + $hasDigit + $hasSymbol) -eq 4)
    
    Write-Verbose "Password generated after $iterations iterations"
    $password | ConvertTo-SecureString -AsPlainText
}