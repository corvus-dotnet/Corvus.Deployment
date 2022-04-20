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

.PARAMETER KeyVaultName
The optional key vault where the password will be stored.

.PARAMETER KeyVaultSecretName
The key vault secret name where the password will be stored.

.OUTPUTS
SecureString

.EXAMPLE

$pwd = New-Password
$pwd = New-Password -Length 18

#>
function New-Password
{
    [CmdletBinding(DefaultParameterSetName="Default", SupportsShouldProcess)]
    param
    (
        [Parameter(ParameterSetName="Default", Position = 0)]
        [Parameter(ParameterSetName="UseKeyVault", Position = 0)]
        [Parameter(Position = 0)]
        [ValidateRange(12, 256)]
        [int] $Length = 16,

        [Parameter(ParameterSetName="Default")]
        [Parameter(ParameterSetName="UseKeyVault")]
        [ValidateNotNull()]
        [char[]] $ValidSymbols = '!@#$%^&*'.ToCharArray(),

        [Parameter(ParameterSetName="Default")]
        [Parameter(ParameterSetName="UseKeyVault")]
        [switch] $PassThru,

        [Parameter(Mandatory=$true, ParameterSetName="UseKeyVault")]
        [string] $KeyVaultName,
        
        [Parameter(Mandatory=$true, ParameterSetName="UseKeyVault")]
        [string] $KeyVaultSecretName
    )

    $useKeyVault = $PSCmdlet.ParameterSetName -eq "UseKeyVault"

    if ($useKeyVault -and $PSCmdlet.ShouldProcess($KeyVaultName, "Connect to key vault")) {
        _EnsureAzureConnection -AzPowerShell | Out-Null
    }
    
    # reference: https://gist.github.com/onlyann/00d9bb09d4b1338ffc88a213509a6caf
    $characterList = 'a'..'z' + 'A'..'Z' + '0'..'9' + $ValidSymbols
    
    $iterations = 0
    do {
        $password = ""
        for ($i = 0; $i -lt $length; $i++) {
            $randomIndex = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(0, $characterList.Length)
            $password += $characterList[$randomIndex]
        }

        $hasLowerChar = $password -cmatch '[a-z]'
        $hasUpperChar = $password -cmatch '[A-Z]'
        $hasDigit = $password -match '[0-9]'
        $hasSymbol = $password.IndexOfAny($ValidSymbols) -ne -1

        $iterations++
    }
    until ($hasLowerChar -and $hasUpperChar -and $hasDigit -and $hasSymbol)
    
    Write-Verbose "Password generated after $iterations iterations"
    $securePassword = $password | ConvertTo-SecureString -AsPlainText
    $password = $null

    if ($useKeyVault) {
        if ($PSCmdlet.ShouldProcess($KeyVaultName, "Store password in key vault")) {
            Write-Host "Storing password in key vault [VaultName=$KeyVaultName, SecretName=$KeyVaultSecretName]"
            Set-AzKeyVaultSecret -VaultName $KeyVaultName `
                                    -Name $KeyVaultSecretName `
                                    -SecretValue $securePassword `
                                    -ContentType "text/plain" `
                | Out-Null
        }
    }

    if ($PassThru) {
        $securePassword
    }
}