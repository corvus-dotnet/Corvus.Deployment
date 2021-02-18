# <copyright file="Corvus.Deployment.Module.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
$script:here = Split-Path -Parent $MyInvocation.MyCommand.Path

$script:functions = Get-ChildItem -Recurse $here/functions -Include *.ps1 | `
                            Where-Object { $_ -notmatch ".Tests.ps1" }

Describe "Corvus.Deployment Module Tests"  {

  Context 'Module Setup' {
    It "has the root module Corvus.Deployment.psm1" {
      "$here/Corvus.Deployment.psm1" | Should -Exist
    }

    It "has the a manifest file of Corvus.Deployment.psd1" {
      "$here/Corvus.Deployment.psd1" | Should -Exist
      "$here/Corvus.Deployment.psd1" | Should -FileContentMatch "Corvus.Deployment.psm1"
    }
    
    It "Corvus.Deployment folder has functions folder" {
      "$here/functions" | Should -Exist
    }

    It "Corvus.Deployment is valid PowerShell code" {
      $psFile = Get-Content -Path "$here/Corvus.Deployment.psm1" -ErrorAction Stop
      $errors = $null
      $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
      $errors.Count | Should -Be 0
    }

  }

  foreach ($functionFile in $functions)
  {
    $script:function = $functionFile.Name
    $script:functionPath = $functionFile.FullName
    $script:functionDir = $functionFile.Directory.FullName
  
    Context "Test Function $function" {
      
      It "$function should exist" {
        $functionPath | Should -Exist
      }

      It "$function should have a copyright block" {
        $functionPath | Should -FileContentMatch 'Copyright \(c\) Endjin Limited'
      }
    
      It "$function should have help block" {
        $functionPath | Should -FileContentMatch '<#'
        $functionPath | Should -FileContentMatch '#>'
      }

      It "$function should have a SYNOPSIS section in the help block" {
        $functionPath | Should -FileContentMatch '.SYNOPSIS'
      }
    
      It "$function should have a DESCRIPTION section in the help block" {
        $functionPath | Should -FileContentMatch '.DESCRIPTION'
      }

      # It "$function should have a EXAMPLE section in the help block" {
      #   $functionPath | Should -FileContentMatch '.EXAMPLE'
      # }
    
      It "$function should be an advanced function" {
        $functionPath | Should -FileContentMatch 'function'
        $functionContent = Get-Content -raw $functionPath
        if ($functionContent -notmatch '#SUPPRESS-ParameterChecks') {
          $functionPath | Should -FileContentMatch 'cmdletbinding'
          $functionPath | Should -FileContentMatch 'param'
        }
      }
      
      It "$function is valid PowerShell code" {
        $psFile = Get-Content -Path $functionPath -ErrorAction Stop
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
        $errors.Count | Should -Be 0
      }

      # This test aims to highlight when functions do not enforce the use of the 'Connect-Azure' function
      # that provides guard rails for ensuring the process is connected to the correct Azure subscription/tenant
      It "$function must validate the Azure connection before using Az PowerShell or the AzureCLI" {
        $functionContent = Get-Content -raw $functionPath
        # Attempt to detect whether the function calls a Az PowerShell Cmdlet
        # NOTE:
        #   Regex looks for references to names following the pattern of Az PowerShell cmdlets (e.g. <verb>-Az<Noun>)
        #   Ignoring references to our 'Invoke-AzCli' cmdlet
        $usesAzPowerShell = $functionContent | Select-String -CaseSensitive -Pattern ".*\w-Az(?!Cli)[A-Z].*"
        if ($usesAzPowerShell) {
          $functionContent | Should -Match "_EnsureAzureConnection"
        }
      }
    }

    # Context "$function has tests" {
    #   It "$($function).Tests.ps1 should exist" {
    #     "$functionDir/$($function).Tests.ps1" | Should -Exist
    #   }
    # }
  
  }

}