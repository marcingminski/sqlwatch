param(
        [string]$ProjectFolder,
        [switch]$TestOnly,
        [string[]]$SqlInstances,
        [string]$CentralRepoInstance

    )

Set-Location -Path $ProjectFolder

$TestFolder = "$($ProjectFolder)\SqlWatch.Test"
$ResultFolder = "$($TestFolder)\Pester.Results"
$ModulesPath = "$($TestFolder)\*.psm1"
$DACPACPath = Get-ChildItem -Recurse -Filter SQLWATCH.dacpac | Sort-Object LastWriteTime -Descending | Select-Object -First 1

$SqlWatchDatabase = "SQLWATCH"

$RemoteInstances = @();
ForEach ($SqlInstance in $SqlInstances) {
    if ($SqlInstance -ne $CentralRepoInstance) {
        $RemoteInstances+= $SqlInstance
    }
}

if (!(Test-Path -Path $ResultFolder)) {
    New-Item -Path $ResultFolder -ItemType Directory
} else {
    Remove-item "$($ResultFolder)\*" -Force -Confirm:$false -Recurse
}

Function Format-ResultsFileName{
    param (
        [string]$TestFile
    )
    $PesterTestFiles = Get-Item $TestFile
    # Build string containing all tests from the input test files so we can have a nice result file name:
    ForEach($PesterTestFile in $PesterTestFiles) {
        $PesterTest+= "SqlWatch." + $($($PesterTestFile.Name -Replace ".ps1","") -Replace "Pester.SqlWatch.","") + "."
    }    
    return $PesterTest.TrimEnd(".")
};

if (-Not $TestOnly) {

    $ErrorActionPreference = "Stop"
    $Database = "SQLWATCH"
    
    foreach ($SqlInstance in $SqlInstances)
    {
        Write-Output "Deploying on $($SqlInstance)"  
        $dbainstance = Connect-DbaInstance -SqlInstance $SqlInstance
    } 

    #$PublishResults = Publish-DbaDacPackage -SqlInstance $SqlInstances -Database $Database -Path $($DACPACPath.FullName) -EnableException
 
}

## Run Test
Write-Output "Testing..."

$ErrorActionPreference = "Continue"

## Copy SqlWatchImport files from the release folder to the test folder becuae we are going to change the app.config:
Get-Childitem -Path "$($ProjectFolder)\RELEASE" -recurse -Filter "SqlWatchImport*" | Copy-Item -Destination $($TestFolder)
Get-Childitem -Path "$($ProjectFolder)\RELEASE" -recurse -Filter "CommandLine*" | Copy-Item -Destination $($TestFolder)

## TEST BATCH
ForEach ($SqlInstance in $SqlInstances) {

    $TestFile = "$($TestFolder)\Pester.SqlWatch.BasicConfig.ps1"
    $PesterTest = Format-ResultsFileName -TestFile $TestFile
    $ResultsFile = "$($ResultFolder)\Pester.Results.$($PesterTest).$($SqlInstance -Replace "\\",'').xml"
    .\SqlWatch.Test\Run-Tests.p5.ps1 -SqlInstance $SqlInstance -SqlWatchDatabase $SqlWatchDatabase -TestFile $TestFile -ResultsFile $ResultsFile -Modules $ModulesPath -RunAsJob    

    $TestFile = "$($TestFolder)\Pester.SqlWatch.ProcedureExecution.ps1"
    $PesterTest = Format-ResultsFileName -TestFile $TestFile
    $ResultsFile = "$($ResultFolder)\Pester.Results.$($PesterTest).$($SqlInstance -Replace "\\",'').xml"
    .\SqlWatch.Test\Run-Tests.p5.ps1 -SqlInstance $SqlInstance -SqlWatchDatabase $SqlWatchDatabase -TestFile $TestFile -ResultsFile $ResultsFile -Modules $ModulesPath -RunAsJob
}
Get-Job | Wait-Job | Receive-Job | Format-Table

## TEST BATCH
ForEach ($SqlInstance in $SqlInstances) {

    $TestFile = "$($TestFolder)\Pester.SqlWatch.BrokerActivation.ps1"
    $PesterTest = Format-ResultsFileName -TestFile $TestFile
    $ResultsFile = "$($ResultFolder)\Pester.Results.$($PesterTest).$($SqlInstance -Replace "\\",'').xml"
    .\SqlWatch.Test\Run-Tests.p5.ps1 -SqlInstance $SqlInstance -SqlWatchDatabase $SqlWatchDatabase -TestFile $TestFile -ResultsFile $ResultsFile -Modules $ModulesPath -RunAsJob        

    $TestFile = "$($TestFolder)\Pester.SqlWatch.Errorlog.ps1"
    $PesterTest = Format-ResultsFileName -TestFile $TestFile
    $ResultsFile = "$($ResultFolder)\Pester.Results.$($PesterTest).$($SqlInstance -Replace "\\",'').xml"
    .\SqlWatch.Test\Run-Tests.p5.ps1 -SqlInstance $SqlInstance -SqlWatchDatabase $SqlWatchDatabase -TestFile $TestFile -ResultsFile $ResultsFile -Modules $ModulesPath -RunAsJob        

    $TestFile = "$($TestFolder)\Pester.SqlWatch.Blockers.ps1"
    $PesterTest = Format-ResultsFileName -TestFile $TestFile
    $ResultsFile = "$($ResultFolder)\Pester.Results.$($PesterTest).$($SqlInstance -Replace "\\",'').xml"
    .\SqlWatch.Test\Run-Tests.p5.ps1 -SqlInstance $SqlInstance -SqlWatchDatabase $SqlWatchDatabase -TestFile $TestFile -ResultsFile $ResultsFile -Modules $ModulesPath -RunAsJob    

    $TestFile = "$($TestFolder)\Pester.SqlWatch.LongQueries.ps1"
    $PesterTest = Format-ResultsFileName -TestFile $TestFile
    $ResultsFile = "$($ResultFolder)\Pester.Results.$($PesterTest).$($SqlInstance -Replace "\\",'').xml"
    .\SqlWatch.Test\Run-Tests.p5.ps1 -SqlInstance $SqlInstance -SqlWatchDatabase $SqlWatchDatabase -TestFile $TestFile -ResultsFile $ResultsFile -Modules $ModulesPath -RunAsJob        

    $TestFile = "$($TestFolder)\Pester.SqlWatch.Design.ps1"
    $PesterTest = Format-ResultsFileName -TestFile $TestFile
    $ResultsFile = "$($ResultFolder)\Pester.Results.$($PesterTest).$($SqlInstance -Replace "\\",'').xml"
    .\SqlWatch.Test\Run-Tests.p5.ps1 -SqlInstance $SqlInstance -SqlWatchDatabase $SqlWatchDatabase -TestFile $TestFile -ResultsFile $ResultsFile -Modules $ModulesPath -RunAsJob

    $TestFile = "$($TestFolder)\Pester.SqlWatch.Checks.ps1"
    $PesterTest = Format-ResultsFileName -TestFile $TestFile
    $ResultsFile = "$($ResultFolder)\Pester.Results.$($PesterTest).$($SqlInstance -Replace "\\",'').xml"
    .\SqlWatch.Test\Run-Tests.p5.ps1 -SqlInstance $SqlInstance -SqlWatchDatabase $SqlWatchDatabase -TestFile $TestFile -ResultsFile $ResultsFile -Modules $ModulesPath -RunAsJob         

}
Get-Job | Wait-Job | Receive-Job | Format-Table

## TEST BATCH
ForEach ($SqlInstance in $SqlInstances) {   

    $TestFile = "$($TestFolder)\Pester.SqlWatch.DataRetention.ps1"
    $PesterTest = Format-ResultsFileName -TestFile $TestFile
    $ResultsFile = "$($ResultFolder)\Pester.Results.$($PesterTest).$($SqlInstance -Replace "\\",'').xml"
    .\SqlWatch.Test\Run-Tests.p5.ps1 -SqlInstance $SqlInstance -SqlWatchDatabase $SqlWatchDatabase -TestFile $TestFile -ResultsFile $ResultsFile -Modules $ModulesPath -RunAsJob   

    $TestFile = "$($TestFolder)\Pester.SqlWatch.TableContent.ps1"
    $PesterTest = Format-ResultsFileName -TestFile $TestFile
    $ResultsFile = "$($ResultFolder)\Pester.Results.$($PesterTest).$($SqlInstance -Replace "\\",'').xml"
    .\SqlWatch.Test\Run-Tests.p5.ps1 -SqlInstance $SqlInstance -SqlWatchDatabase $SqlWatchDatabase -TestFile $TestFile -ResultsFile $ResultsFile -Modules $ModulesPath -RunAsJob       

    $TestFile = "$($TestFolder)\Pester.SqlWatch.ApplicationLog.ps1"
    $PesterTest = Format-ResultsFileName -TestFile $TestFile
    $ResultsFile = "$($ResultFolder)\Pester.Results.$($PesterTest).$($SqlInstance -Replace "\\",'').xml"
    .\SqlWatch.Test\Run-Tests.p5.ps1 -SqlInstance $SqlInstance -SqlWatchDatabase $SqlWatchDatabase -TestFile $TestFile -ResultsFile $ResultsFile -Modules $ModulesPath -RunAsJob   

}
Get-Job | Wait-Job | Receive-Job | Format-Table

##############################################################################################################################################################
## Sixth batch (Single Central Repository):
$SqlInstance = $CentralRepoInstance

## set SqlWatchImport.exe configuration
## Dedicate SQL2017 as central repository:
$SqlWatchImportConfigFile = "$($TestFolder)\SqlWatchImport.exe.config" 
$SqlWatchImportConfig = New-Object XML
$SqlWatchImportConfig.Load($SqlWatchImportConfigFile)

$node = $SqlWatchImportConfig.SelectSingleNode('configuration/appSettings/add[@key="CentralRepositorySqlInstance"]')
$node.Attributes['value'].Value = $CentralRepoInstance

$node = $SqlWatchImportConfig.SelectSingleNode('configuration/appSettings/add[@key="CentralRepositorySqlDatabase"]')
$node.Attributes['value'].Value = $SqlWatchDatabase

$node = $SqlWatchImportConfig.SelectSingleNode('configuration/appSettings/add[@key="LogFile"]')
$node.Attributes['value'].Value = "$($TestFolder)\SqlWatchImport.log"

$SqlWatchImportConfig.Save($SqlWatchImportConfigFile)

$TestFile = "$($TestFolder)\Pester.SqlWatch.SqlWatchImport.ps1"
$PesterTest = Format-ResultsFileName -TestFile $TestFile
$ResultsFile = "$($ResultFolder)\Pester.Results.$($PesterTest).$($SqlInstance -Replace "\\",'').xml"
.\SqlWatch.Test\Run-Tests.p5.ps1 -SqlInstance $SqlInstance -SqlWatchDatabase $SqlWatchDatabase -TestFile $TestFile -ResultsFile $ResultsFile -Modules $ModulesPath -RemoteInstances $RemoteInstances -SqlWatchImportPath $($TestFolder)

##############################################################################################################################################################

Get-Job | Wait-Job | Receive-Job | Format-Table
Get-Job | Format-Table -Autosize

Set-Location -Path $ProjectFolder

## Get XMLS to push to AppVeyor
$xmls = get-item -path "$($ResultFolder)\Pester*.xml"

## Upload Nunit tests to Appveyor:
foreach ($xml in $xmls) {
    (New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $xml))
      if ($res.FailedCount -gt 0) { 
          throw "$($res.FailedCount) tests failed."
      }
}

## Generate html reports:
Remove-Item .\SqlWatch.Test\CommandLine.xml -Force -Confirm:$false
.\SqlWatch.Test\ReportUnit.exe "$($ResultFolder)" "$($ResultFolder)\html"

## Copy source xml and any logs files into the Report folder:
Copy-Item .\SqlWatch.Test\*.log "$($ResultFolder)"

## Zip the report folder and upload to AppVeyor as Artifact
Compress-Archive -Path "$($ResultFolder)" -DestinationPath "$($ResultFolder)\SqlWatch.Pester.Test.Results.$(Get-Date -Format "yyyyMMddHHmmss").zip"
Push-AppveyorArtifact $(Get-Item "$($ResultFolder)\SqlWatch.Pester.Test.Results.*.zip")

## Push Nunit results to testcase (disabled until testcase is fixed, bug logged with testcase)
.\SqlWatch.Test\testspace config url marcingminski.testspace.com
.\SqlWatch.Test\testspace --version
.\SqlWatch.Test\testspace "[SqlWatch.Test.SQL2017]c:\projects\sqlwatch\SqlWatch.Test\Pester.Results\*SQL2017.xml" "[SqlWatch.Test.SQL2016]c:\projects\sqlwatch\SqlWatch.Test\Pester.Results\*SQL2016.xml" "[SqlWatch.Test.SQL2014]c:\projects\sqlwatch\SqlWatch.Test\Pester.Results\*SQL2014.xml" "[SqlWatch.Test.SQL2012SP1]c:\projects\sqlwatch\SqlWatch.Test\Pester.Results\*SQL2012SP1.xml"

<# We are going to pass the build until I got all the tests sorted out
-- with testspace now working, we can pass the build purely based on the build
-- as testspace will fail the PR independently if tests fail

## If any of the background jobs failed, fails the entire deployment
If ((Get-Job | Where-Object {$_.State -eq "Failed"}).Count -gt 0){
    Get-Job | Foreach-Object {$_.JobStateInfo.Reason}
    $env:HAS_ERRORS="Yes"
    $HasErrors = $true
}

$ErrorActionPreference = "Stop"
If ($HasErrors = $true) {
   Throw "Not all tests passed"
   $host.SetShouldExit(1)
}#>

<#$blockRdp = $true; iex ((new-object net.webclient).DownloadString('https://raw.githubusercontent.com/appveyor/ci/master/scripts/enable-rdp.ps1'))#>
