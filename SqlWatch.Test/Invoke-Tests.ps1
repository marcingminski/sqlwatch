
param(
        [string]$SqlInstance,
        [string]$SqlWatchDatabase
)

$MinSqlUpHours = 2;

#$sql = "select datediff(hour,install_date,getdate()) from vw_sqlwatch_app_version"
#$result = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
#$LookBackHours = $result.column1

$LookBackHours = 2

$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

$ChecksFolder = $PSScriptRoot

cd $PSScriptRoot
$CustomPesterChecksPath = "$($ChecksFolder)\Pester.SqlWatch.Test.Checks.ps1";

$Checks = "IndentityUsage","FKCKTrusted"

## Disable sqlwatch jobs as they may clash with tests:
$sql = "select name
from msdb.dbo.sysjobs
where name like 'SQLWATCH%'
and enabled = 1"

$jobs = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

Foreach ($job in $jobs) {
    
        $sql = "EXEC msdb.dbo.sp_update_job @job_name = N'$($job.name)', @enabled = 0;"
        Invoke-SqlCmd -ServerInstance SQL-2 -Database SQLWATCH -Query $sql
    }

## custom pester scripts
Write-Output "Custom SqlWatch Tests"
$outputfile1 = "$ChecksFolder\Result.SqlWatch.Test.Checks.xml"
Invoke-Pester -Script @{
        Path=$CustomPesterChecksPath;
        Parameters=@{
                SqlInstance=$SqlInstance;
                SqlWatchDatabase=$SqlWatchDatabase;
                MinSqlUpHours=$MinSqlUpHours;
                LookBackHours=$LookBackHours
            }
        } -OutputFormat  NUnitXml -OutputFile $outputfile1 -Show All -Strict

## use dbachecks where possible and only build our own pester checks for things not already covered by dbachecks
Write-Output "dbachecks"
$outputfile2 = ("$ChecksFolder\Result.SqlWatch.DbaChecks.xml")
Invoke-DbcCheck -Check $Checks -SqlInstance $SqlInstance -Database $SqlWatchDatabase -OutputFormat  NUnitXml -OutputFile $outputfile2 -Show All -Strict

#re-enable sqlwatch jobs:
Foreach ($job in $jobs) {
    
        $sql = "EXEC msdb.dbo.sp_update_job @job_name = N'$($job.name)', @enabled = 1;"
        Invoke-SqlCmd -ServerInstance SQL-2 -Database SQLWATCH -Query $sql
    }

#cd C:\TEMP
.\ReportUnit.exe $outputfile1
.\ReportUnit.exe $outputfile2

