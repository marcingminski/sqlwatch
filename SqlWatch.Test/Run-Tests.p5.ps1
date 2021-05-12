param(
        [string]$SqlInstance,
        [string]$SqlWatchDatabase,
        [string]$TestFilePath,
        [string]$ResultsPath,
        [string[]]$IncludeTags,
        [string[]]$ExcludeTags,
        [switch]$RunAsJob,
        [string[]]$RemoteInstances,
        [string]$SqlWatchImportPath
)


If ($RunAsJob) {
    $JobName = "Tests@" + $SqlInstance
    Start-Job -Name $JobName -ScriptBlock {

        param(
            [string]$SqlInstance,
            [string]$SqlWatchDatabase,
            [string]$TestFilePath,
            [string]$ResultsPath,
            [string[]]$IncludeTags,
            [string[]]$ExcludeTags,
            [string[]]$RemoteInstances,
            [string]$SqlWatchImportPath
        )

        Import-Module Pester

        $TestFile = Get-Item -Path $TestFilePath
        $ResultsFile = "$($TestFile -Replace 'ps1','result').$($SqlInstance -Replace '\\','').xml"        

        $configuration = New-PesterConfiguration
        $configuration.TestResult.Enabled = $true
        $configuration.TestResult.OutputPath = $ResultsFile
        $configuration.TestResult.TestSuiteName = "Pester: $($SqlInstance)"
        $configuration.Output.Verbosity = "Detailed"
        $configuration.CodeCoverage.Enabled = $false
        $configuration.Filter.Tag = $IncludeTags
        $configuration.Filter.ExcludeTag = $ExcludeTags
        $configuration.Run.Exit = $false
        $configuration.Run.Container = @(
            ( New-PesterContainer -Path $($TestFile.FullName) -Data @{ 
                    SqlInstance = $SqlInstance;
                    SqlWatchDatabase = $SqlWatchDatabase;
                    SqlWatchDatabaseTest = "SQLWATCH_TEST"
                    RemoteInstances = $RemoteInstances
                    SqlWatchImportPath = $SqlWatchImportPath;
                } )
        )
            
        Invoke-Pester -Configuration $configuration 
        } -ArgumentList $SqlInstance,$SqlWatchDatabase,$TestFilePath,$ResultsPath,$IncludeTags,$ExcludeTags,$RemoteInstances, $SqlWatchImportPath
    
} else {
    <#This is repeated and the same as in the Start-Job. I do not know how to make the Pester Configuration generic and Pass into the Job as argument, I am getting:
    Cannot process argument transformation on parameter 'Configuration'. Cannot convert value "PesterConfiguration" to type "PesterConfiguration". Error: "Cannot convert the "PesterConfiguration" value 
    of type "Deserialized.PesterConfiguration" to type "PesterConfiguration"." #>

    $TestFile = Get-Item -Path $TestFilePath
    $ResultsFile = "$($TestFile -Replace 'ps1','result').$($SqlInstance -Replace '\\','').xml"

    $configuration = New-PesterConfiguration
    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputPath = $ResultsFile
    $configuration.TestResult.TestSuiteName = "Pester: $($SqlInstance)"    
    $configuration.Output.Verbosity = "Detailed"
    $configuration.CodeCoverage.Enabled = $false
    $configuration.Filter.Tag = $IncludeTags
    $configuration.Filter.ExcludeTag = $ExcludeTags
    $configuration.Run.Exit = $false
    $configuration.Run.Container = @(
        ( New-PesterContainer -Path $($TestFile.FullName) -Data @{ 
                SqlInstance = $SqlInstance;
                SqlWatchDatabase = $SqlWatchDatabase;
                SqlWatchDatabaseTest = "SQLWATCH_TEST";
                RemoteInstances = $RemoteInstances
                SqlWatchImportPath = $SqlWatchImportPath;
            } )
    )

    Invoke-Pester -Configuration $configuration
}
