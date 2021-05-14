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

Describe "$($SqlInstance): ERRORLOG Capture" -Tag "ERRORLOG" {

    It 'Logging in with incorrect user' {
        $sql = "select 1"
        { Invoke-SqlCmd -ServerInstance $SqlInstance -Database master -Query $sql -Username "InvalidUserTest" -Password "Password" -ErrorAction Stop -OutputSqlErrors $true } | Should -Throw
    }      

    It 'Login Failed ERRORLOG entries "<_.Text>"' -ForEach $(Get-SqlServerErrorLogRecordsDuringTest -String1 'Login failed' -String2 '') {
        $_.Text | Should -BeLike '*Login failed*'
    }

    It 'Capture ERRORLOG into SQLWATCH' {
        $sql = "select cnt=count(*) from [dbo].[sqlwatch_logger_errorlog]"
        $Errorlog1 = Invoke-SqlWatchCmd -Query $sql

        Start-Sleep -s 1
        $sql = "exec [dbo].[usp_sqlwatch_logger_errorlog];"
        { Invoke-SqlWatchCmd -Query $sql } | Should -Not -Throw
    }

    It 'Errorlog record count increased' {
        $sql = "select cnt=count(*) from [dbo].[sqlwatch_logger_errorlog]"
        $Errorlog2 = Invoke-SqlWatchCmd -Query $sql

        $Errorlog2.cnt | Should -BeGreaterThan $Errorlog1.cnt
    }    
}