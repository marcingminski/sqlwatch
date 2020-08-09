$SqlInstance = "sqlwatch-test-1";
$SqlWatchDatabase = "SQLWATCH";
$MinSqlUpHours = 2;

$ChecksFolder = "C:\Users\marcin\Documents\GitHub\sqlwatch\sqlwatch\SqlWatch.Test"
$CustomPesterChecksPath = "$($ChecksFolder)\Pester.SqlWatch.Test.Checks.ps1";

$Checks = "FailedJob","IndentityUsage","DuplicateIndex","UnusedIndex","DisabledIndex","FKCKTrusted"

## custom pester scripts
Write-Output "Custom SqlWatch Tests"
$outputfile1 = "$ChecksFolder\Result.SqlWatch.Test.Checks.xml"
Invoke-Pester -Script @{Path=$CustomPesterChecksPath;Parameters=@{SqlInstance=$SqlInstance;SqlWatchDatabase=$SqlWatchDatabase;MinSqlUpHours=$MinSqlUpHours}} -OutputFormat  NUnitXml -OutputFile $outputfile1 -Show Summary -Strict

## use dbachecks where possible and only build our own pester checks for things not already covered by dbachecks
Write-Output "dbachecks"
$outputfile2 = ("$ChecksFolder\Result.SqlWatch.DbaChecks.xml")
Invoke-DbcCheck -Check $Checks -SqlInstance $SqlInstance -Database $SqlWatchDatabase -OutputFormat  NUnitXml -OutputFile $outputfile2 -Show Summary -Strict


cd C:\TEMP
.\ReportUnit.exe $outputfile1
.\ReportUnit.exe $outputfile2

