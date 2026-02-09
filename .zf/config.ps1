<#
This example demonstrates a software build process using the 'ZeroFailed.Build.DotNet' extension
to provide the features needed when building a .NET solutions.
#>

$zerofailedExtensions = @(
    @{
        # References the extensions from its GitHub repository. If not already installed, use latest version from 'main' will be downloaded.
        Name = "ZeroFailed.Build.PowerShell"
        GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.PowerShell"
        GitRef = "main"
    }
    @{
        Name = "ZeroFailed.Build.Containers"
        GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.Containers"
        GitRef = "main"
    }
    @{
        Name = "ZeroFailed.Build.GitHub"
        GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.GitHub.git"
        GitRef = "main"
    }
)

# Load the tasks and process
. ZeroFailed.tasks -ZfPath $here/.zf

#
# Build process configuration
#
#
# Build process control options
#
$SkipInit = $false
$SkipVersion = $false
$SkipBuild = $false
$CleanBuild = $Clean
$SkipGeneratePSMarkdownDocs = $true
$SkipTest = $false
$SkipTestReport = $false
$SkipAnalysis = $false
$SkipPackage = $false
$SkipPublish = $true

# Set the required build options
$PesterTestsDir = Join-Path $here 'module'
$PesterCodeCoveragePaths = Join-Path $PesterTestsDir 'functions'
$PesterCodeCoverageThreshold = 30
$PesterExcludeTagFilter = @('Integration')
$PowerShellModulesToPublish = @(
    @{
        ModulePath = "$here/module/Corvus.Deployment.psd1"
        FunctionsToExport = @("*")
        CmdletsToExport = @()
        AliasesToExport = @(
            "Get-AzdoOrganizationUrl"
        )
    }
)
$PSMarkdownDocsFlattenOutputPath = $true
$PSMarkdownDocsOutputPath = './docs/functions'
$PSMarkdownDocsIncludeModulePage = $false
$CreateGitHubRelease = $false   # only run for CI build by default

$ContainerRegistryType = 'docker'
$ContainerImageVersionOverride = 'dev'  # used for local builds only to avoid tag proliferation in the local image store
$ContainersToBuild = @(
    @{
        Dockerfile = './Dockerfile'
        ImageName = 'endjin/corvus.deployment'
        ContextDir = '.'
        Arguments = @{}
    }
)

task . FullBuild

#
# Build Process Extensibility Points - uncomment and implement as required
#

# task RunFirst {}
# task PreInit {}
# task PostInit {}
# task PreVersion {}
# task PostVersion {}
# task PreBuild {}
# task PostBuild {}
# task PreTest {}
# task PostTest {}
# task PreTestReport {}
# task PostTestReport {}
# task PreAnalysis {}
# task PostAnalysis {}
# task PrePackage {}
# task PostPackage {}
# task PrePublish {}
# task PostPublish {}
# task RunLast {}