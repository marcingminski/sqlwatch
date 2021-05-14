param(
    [string]$SqlInstance,
    [string]$SqlWatchDatabase,
    [string]$SqlWatchDatabaseTest,
    [string[]]$RemoteInstances,
    [string]$SqlWatchImportPath,
    [string]$Modules
)


Get-Item -Path $Modules | Import-Module -Force

$global:SqlInstance=$SqlInstance
$global:SqlWatchDatabase=$SqlWatchDatabase
$global:OutputSqlErrors=$false

$TestDatabaseName = New-SqlWatchTestDatabase
$global:SqlWatchDatabaseTest=$TestDatabaseName

Describe "$($SqlInstance): Testing Long Queries Capture" -Tag 'LongQueries' {

    Context 'Generating Long Query' {

        It "Running 1st Long Query Lasting over 5 seconds" {

            $n = 1
            $duration = Measure-Command{}
            
            while ($duration.TotalSeconds -lt 6 -and $n -lt 30) {
                $sql = "select top $($n)00000 a.*
                into #t
                from sys.all_objects a
                cross join sys.all_objects"
        
                $duration = Measure-Command { Invoke-SqlWatchTestCmd -Query $sql }
                $n+=$n;
            }

            $duration.TotalSeconds | Should -BeGreaterThan 5 -Because "To trigger long query XES the query must last over 5 seconds"
        }

        It "Running 2nd Long Query Lasting over 5 seconds" {

            $n = 1
            $duration = Measure-Command{}
            
            while ($duration.TotalSeconds -lt 6 -and $n -lt 30) {
                $sql = "select top $($n)00000 a.*
                into #t
                from sys.all_objects a
                cross join sys.all_objects"
        
                $duration = Measure-Command { Invoke-SqlWatchTestCmd -Query $sql }
                $n+=$n;
            }

            $duration.TotalSeconds | Should -BeGreaterThan 5 -Because "To trigger long query XES the query must last over 5 seconds"
        }

    }


    Context 'Checking that we are able to read XES and offload Long Queries to table' {

        It "Getting Long Queries from XES" {
            $sql = "exec [dbo].[usp_sqlwatch_logger_xes_long_queries];"
            { Invoke-SqlWatchCmd -Query $sql -ErrorAction Stop } | Should -Not -Throw
        }

        It "New Long Queries recorded" {

            $sql = "select cnt=count(*) 
                    from [dbo].[sqlwatch_logger_xes_long_queries] 
                    where [event_time] >= (
                            select max(date) 
                            from [$($global:SqlWatchDatabaseTest)].dbo.[sqlwatch_pester_ref]
                            )"
            $result = Invoke-SqlWatchCmd -Query $sql
            $result.cnt | Should -BeGreaterThan 0 -Because 'Long Query count should have increased' 

        }

        It "Only queries lasting more than 5 seconds" {

            $sql = "select duration_ms=min(duration_ms) from [dbo].[sqlwatch_logger_xes_long_queries]"
            $result = Invoke-SqlWatchCmd -Query $sql
            $result.duration_ms | Should -BeGreaterThan 5000 -Because 'Long query threshold is 5s'
        }
    }
}