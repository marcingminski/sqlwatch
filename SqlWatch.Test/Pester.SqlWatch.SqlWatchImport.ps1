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

        It 'Instance <_> is not in the config table' -ForEach $RemoteInstances {
            $sql = "select cnt=count(*) from dbo.sqlwatch_config_sql_instance where [sql_instance] = '$_'"
            $result = Invoke-SqlWatchCmd -Query $sql

            $result.cnt | Should -Be 0
        }

        It 'Adding remote instance <_> to the central repository should not throw' -ForEach $RemoteInstances {

            ## the output is an array of lines, we have to convert to a single string using -join:
            $output = (& "$($SqlWatchImportPath)\SqlWatchImport.exe" --add -s $_ -d $($global:SqlWatchDatabase)) -join ""
            $output | Should -Match ".OK"
        }

        It 'Instance <_> is in the config table' -ForEach $RemoteInstances {
            $sql = "select cnt=count(*) from dbo.sqlwatch_config_sql_instance where [sql_instance] = '$_'"
            $result = Invoke-SqlWatchCmd -Query $sql

            $result.cnt | Should -Be 1
        }        
    }

    Context 'Importing data with SqlWatchImport' {

        It 'Running SqlWatchImport.exe should not throw' {

            ## the output is an array of lines, we have to convert to a single string using -join:
            $output = (& "$($SqlWatchImportPath)\SqlWatchImport.exe") -join ""
            $output | Should -Not -Match "Exception|ERROR|Fail"
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