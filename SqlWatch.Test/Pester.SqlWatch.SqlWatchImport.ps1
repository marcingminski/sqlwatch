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

$TestDatabaseName = New-SqlWatchTestDatabase
$global:SqlWatchDatabaseTest=$TestDatabaseName

Describe "$($SqlInstance): SqlWatchImport.exe" -Tag "SqlWatchImport" {

    Context 'Adding remote instances' {

        It 'Instance <_> does not exist in the config table' -ForEach $RemoteInstances {
            $sql = "select cnt=count(*) from dbo.sqlwatch_config_sql_instance where [sql_instance] = '$_'"
            $result = Invoke-SqlWatchCmd -Query $sql

            $result.cnt | Should -Be 0
        }

        It 'Adding remote instance <_> to the central repository should not throw' -ForEach $RemoteInstances {

            $Arguments = "--add -s $_ -d $($global:SqlWatchDatabase)"

            { Start-Process -FilePath "$($SqlWatchImportPath)\SqlWatchImport.exe"  -ArgumentList $Arguments -NoNewWindow -Wait } | Should -Not -Throw
        }

        It 'Instance <_> was added to the config table' -ForEach $RemoteInstances {
            $sql = "select cnt=count(*) from dbo.sqlwatch_config_sql_instance where [sql_instance] = '$_'"
            $result = Invoke-SqlWatchCmd -Query $sql

            $result.cnt | Should -Be 1
        }        
    }

    Context 'Importing data with SqlWatchImport' {

        It 'Running SqlWatchImport.exe should not throw' {

            { Start-Process -FilePath "$($SqlWatchImportPath)\SqlWatchImport.exe"  -NoNewWindow -Wait } | Should -Not -Throw -Because "this would mean that the application is crashing and not handling errors. No matter what happens, it should exit gracefuly and log errors to the log"
        }

        It 'LogFile should have no errors' {

            $SqlWatchImportLogErrors = Get-Content -Path "$($SqlWatchImportPath)\SqlWatchImport.log" | ForEach-Object {
                if ($_ -NotLike "*DumpDataOnError*" -and ($_ -like "*Exception*" -or $_ -like "*ERROR*")) {
                    $_
                }
            } 
            $SqlWatchImportLogErrors | Should -BeNullOrEmpty
        }

        It 'Instance <_> should have new headers' -ForEach $RemoteInstances {
            $sql = "select cnt=count(*) from sqlwatch_logger_snapshot_header where [sql_instance] = '$_'"
            $result = Invoke-SqlWatchCmd -Query $sql

            $result.cnt | Should -BeGreaterThan 0
        }
    }

    Context 'Removing Remote Instance' {

        It 'Removing remote instance <_> from the central repository should not throw' -ForEach $RemoteInstances {

            $sql = "delete from [dbo].[sqlwatch_config_sql_instance] where sql_instance = '$_'"
            { Invoke-SqlWatchCmd -Query $sql } | Should -Not -Throw
        }        

    }
}