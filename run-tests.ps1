$here = Split-Path -Parent $MyInvocation.MyCommand.Path

invoke-pester $here/module/Corvus.Deployment.Module.Tests.ps1 -Output Detailed
