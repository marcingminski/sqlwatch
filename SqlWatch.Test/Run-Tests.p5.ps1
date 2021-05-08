param(
        [string]$SqlInstance,
        [string]$SqlWatchDatabase,
        [string]$TestFilePath,
        [string]$ResultsPath,
        [string[]]$IncludeTags,
        [string[]]$ExcludeTags
)

$TestFile = Get-Item -Path $TestFilePath
$ResultsFile = "$($TestFile -Replace 'ps1','result').$($SqlInstance -Replace '\\','').xml"

$configuration = New-PesterConfiguration
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputPath = $ResultsFile
$configuration.Output.Verbosity = "Detailed"
$configuration.CodeCoverage.Enabled = $false
$configuration.Filter.Tag = $IncludeTags
$configuration.Filter.ExcludeTag = $ExcludeTags
$configuration.Run.Exit = $false
$configuration.Run.Container = @(
    ( New-PesterContainer -Path $($TestFile.FullName) -Data @{ SqlInstance = $SqlInstance; SqlWatchDatabase = $SqlWatchDatabase } )
)

Invoke-Pester -Configuration $configuration