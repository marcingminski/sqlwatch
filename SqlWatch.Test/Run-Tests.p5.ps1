param(
        [string]$SqlInstance,
        [string]$SqlWatchDatabase,
        [string]$TestFilePath,
        [string]$ResultsPath,
        [string[]]$IncludeTags,
        [string[]]$ExcludeTags,
        [switch]$RunAsJob
)

##----------------------------------------------------------------------------------------------
## Prepare environment and tests data
##----------------------------------------------------------------------------------------------

$sql = "select Hours=datediff(hour,sqlserver_start_time,getdate()) from sys.dm_os_sys_info"
$SqlUptime = Invoke-SqlCmd -ServerInstance $SqlInstance -Database master -Query $sql

<#
    Create pester table to store results and other data.
    This used to be in its own database but there is no need for another databae project.
    Whilst we do need a separate database to create blocking chains (becuase sqlwatch has RCSI, 
    we can just create it on the fligh here.
    The benefit of this approach is that we can just create tables for the purpose of the test in one place here, 
    rather than having to manage separate database project. The original idea was to move some of the testing stuff
    from the SQLWATCH database but I will move it all here rather than separate database.
#>

$sql = "if not exists (select * from sys.databases where name = '$($SqlWatchDatabaseTest)') 
    begin
        create database [$($SqlWatchDatabaseTest)]
    end;
    ALTER DATABASE [$($SqlWatchDatabaseTest)] SET READ_COMMITTED_SNAPSHOT OFF;
    ALTER DATABASE [$($SqlWatchDatabaseTest)] SET RECOVERY SIMPLE ;"

Invoke-Sqlcmd -ServerInstance $SqlInstance -Database master -Query $sql

#Create table to store reference data for other tests where required:
$sql = "if not exists (select * from sys.tables where name = 'sqlwatch_pester_ref')
begin
    CREATE TABLE [dbo].[sqlwatch_pester_ref]
    (
        [date] datetime NOT NULL,
        [test] varchar(255) not null,
    );    

    create index idx_sqlwatch_pester_ref_test
        on [dbo].[sqlwatch_pester_ref] ([test]) include ([date])
end;

insert into [dbo].[sqlwatch_pester_ref] (date,test)
values (getutcdate(),'Test Start')"

Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabaseTest -Query $sql

##----------------------------------------------------------------------------------------------

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
            [int]$SqlUptimeHours
        )

        Import-Module Pester

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
            ( New-PesterContainer -Path $($TestFile.FullName) -Data @{ 
                    SqlInstance = $SqlInstance;
                    SqlWatchDatabase = $SqlWatchDatabase;
                    SqlWatchDatabaseTest = "SQLWATCH_TEST";
                    SqlUptimeHours = $SqlUptimeHours;
                } )
        )
            
        Invoke-Pester -Configuration $configuration 
        } -ArgumentList $SqlInstance,$SqlWatchDatabase,$TestFilePath,$ResultsPath,$IncludeTags,$ExcludeTags, $SqlUptime.Hours
    
} else {
    <#This is repeated and the same as in the Start-Job. I do not know how to make the Pester Configuration generic and Pass into the Job as argument, I am getting:
    Cannot process argument transformation on parameter 'Configuration'. Cannot convert value "PesterConfiguration" to type "PesterConfiguration". Error: "Cannot convert the "PesterConfiguration" value 
    of type "Deserialized.PesterConfiguration" to type "PesterConfiguration"." #>

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
        ( New-PesterContainer -Path $($TestFile.FullName) -Data @{ 
                SqlInstance = $SqlInstance;
                SqlWatchDatabase = $SqlWatchDatabase;
                SqlWatchDatabaseTest = "SQLWATCH_TEST";
                SqlUptimeHours = $SqlUptime.Hours;
            } )
    )

    Invoke-Pester -Configuration $configuration
}
