cd C:\Users\marcin\Documents\GitHub\sqlwatch\sqlwatch\SqlWatch.Test

$SqlInstance = "localhost"
$SqlWatchDatabase = "SQLWATCH"
$MinSqlUpHours = 2;

#$sql = "select datediff(hour,install_date,getdate()) from vw_sqlwatch_app_version"
#$result = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
#$LookBackHours = $result.column1

$LookBackHours = 2

$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

$ChecksFolder = $PSScriptRoot
$CustomPesterChecksPath = "$($ChecksFolder)\Pester.SqlWatch.Test.Checks.ps1";

$Checks = "IndentityUsage","FKCKTrusted"

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


cd C:\TEMP
.\ReportUnit.exe $outputfile1
.\ReportUnit.exe $outputfile2

