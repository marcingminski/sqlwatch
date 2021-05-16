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
            ## the output when using a command line option is always 0 and it just returns errors as a string. 
            ## This is a bug that I need to fix, in the meantime we have to match the string and look for OK which indicates command completed OK
            $output = (& "$($SqlWatchImportPath)\SqlWatchImport.exe" --add -s $_ -d $($global:SqlWatchDatabase)) -join "`n`r"
            $output | Should -Match ".OK"
        }

        It 'Instance <_> is in the config table' -ForEach $RemoteInstances {
            $sql = "select cnt=count(*) from dbo.sqlwatch_config_sql_instance where [sql_instance] = '$_'"
            $result = Invoke-SqlWatchCmd -Query $sql

            $result.cnt | Should -Be 1
        }        
    }

    Context 'Importing data from remote instances' {

        $m=3
        for ( $i = 0; $i -lt $m; $i++) {
            It "Running SqlWatchImport.exe should not throw on run $($i+1)" {

                $sql = "select cnt=count(*) from sqlwatch_logger_snapshot_header where [sql_instance] = '$_'"
                $headercountbaseline = Invoke-SqlWatchCmd -Query $sql

                ## the output is an array of lines, we have to convert to a single string using -join:
                $output = (& "$($SqlWatchImportPath)\SqlWatchImport.exe") -join "`n`r" 
                $SqlWatchImportExitCode = $LastExitCode
                
                if ($SqlWatchImportExitCode -ne 0) {
                    $output | Should -Not -Match "."
                } else {
                    $SqlWatchImportExitCode | Should -Be 0
                    }                                
            }

            It "Instance <_> should have new headers after run $($i+1)" -ForEach $RemoteInstances {
                $sql = "select cnt=count(*) from sqlwatch_logger_snapshot_header where [sql_instance] = '$_'"
                $result = Invoke-SqlWatchCmd -Query $sql

                $result.cnt | Should -BeGreaterThan $headercountbaseline.cnt
            }              
            Start-Sleep -s 6
        }

        <#
        It 'LogFile should have no errors' -Skip {

            $SqlWatchImportLogErrors = Get-Content -Path "$($SqlWatchImportPath)\SqlWatchImport.log" | ForEach-Object {
                if ($_ -NotLike "*DumpDataOnError*" -and ($_ -like "*Exception*" -or $_ -like "*ERROR*")) {
                    $_
                }
            } 
            $SqlWatchImportLogErrors | Should -BeNullOrEmpty
        }        
        #>
    }

    <#
    Context 'Removing Remote Instance' {

        It 'Removing remote instance <_> from the central repository should not throw' -ForEach $RemoteInstances -Skip {

            $sql = "delete from [dbo].[sqlwatch_config_sql_instance] where sql_instance = '$_'"
            { Invoke-SqlWatchCmd -Query $sql } | Should -Not -Throw
        }        

    }    
    #>

}