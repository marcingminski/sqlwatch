
param(
        [string]$SqlInstance,
        [string]$SqlWatchDatabase,
        [string]$SqlWatchDatabaseTest
)

#https://sqlnotesfromtheunderground.wordpress.com/2017/10/26/publish-pester-results-to-anything/
function ParsePesterXML {
        <#
        .SYNOPSIS 
        Converts Pester XML output file into a simplified result set
        .DESCRIPTION
        Reads the .xml output (in NUNIT format) into memory and then parses out the results into a human readable form. 
        Currently only desinged to used a single Describe in the pester script.
        .PARAMETER XMLFile
        File path to the pester -output .xml file
        .PARAMETER Server
        As we are running the same test against multiple servers this value lets you populate the server the test is ran against
        .PARAMETER Summary
        switch to say if you want a summary of Total tests, failures, errors. compared the standard breakdown of each test
        .NOTES 
        Author: Stephen.Bennett
        .EXAMPLE   
        Parse-PesterXML -XMLFile "C:\Temp\report.xml" -Server "Test" -Summary | ft
        reads in the c:\temp\report.xml output from a pester test and creates an output (formatted as table)
            
        #>
            param (
                        [parameter(Mandatory = $true)]
                [string]$XMLFile,
                [string]$Server,
                [switch]$Summary = $false  
            )
            process 
            {
                if (!(Test-Path $XMLFile))
                {
                    Write-Warning "Failed to find file you supplied.. pls try again"
                }
                
                ## read
                [xml]$xml = Get-Content $XMLFile
                
                if ($Summary -eq $false)
                {
        
                    $results = $xml.'test-results'.'test-suite'.results.'test-suite'.results.'test-suite'.results.'test-suite'.results
        
                    foreach ($r in $results.'test-case')
                    {
                        $out = [pscustomobject]@{
                            Server = $server
                            User = $xml.'test-results'.environment.user
                            DateTime = $xml.'test-results'.date
                            Context = $results = $xml.'test-results'.'test-suite'.results.'test-suite'.name
                            TestName = $r.description
                            TestResult = $r.result
                            TestTime = $r.time
                        }
                        $out
                    }
                }
                else
                {
                    $out = [pscustomobject]@{
                        Server = $Server
                        Total = $xml.'test-results'.total
                        Failure = $xml.'test-results'.failures
                        Error = $xml.'test-results'.errors
                    }
                    $out
                }
            } # process
        } # function


#I have dbatools installed byt get error The term 'Out-DbaDataTable' is not recognized as the name of a cmdlet, function, script file, or operable program.
Function Out-DbaDataTable
        {
        <#
        .SYNOPSIS
        Creates a DataTable for an object
             
        .DESCRIPTION
        Creates a DataTable based on an objects properties. This allows you to easily write to SQL Server tables
             
        Thanks to Chad Miller, this script is all him. https://gallery.technet.microsoft.com/scriptcenter/4208a159-a52e-4b99-83d4-8048468d29dd
         
        .PARAMETER InputObject
        The object to transform into a DataTable
             
        .NOTES
        dbatools PowerShell module (https://dbatools.io)
        Copyright (C) 2016 Chrissy LeMaire
        This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
        This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
        You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.
         
        .LINK
         https://dbatools.io/Out-DbaDataTable
         
        .EXAMPLE
        Get-Service | Out-DbaDataTable
         
        Creates a $datatable based off of the output of Get-Service
             
        .EXAMPLE
        Out-DbaDataTable -InputObject $csv.cheesetypes
         
        Creates a DataTable from the CSV object, $csv.cheesetypes
             
        .EXAMPLE
        $dblist | Out-DbaDataTable
         
        Similar to above but $dbalist gets piped in
             
        #>    
            [CmdletBinding()]
            param (
                [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
                [PSObject[]]$InputObject
            )
            
            BEGIN
            {
                function Get-Type
                {
                    param ($type)
                    
                    $types = @(
                        'System.Boolean',
                        'System.Byte[]',
                        'System.Byte',
                        'System.Char',
                        'System.Datetime',
                        'System.Decimal',
                        'System.Double',
                        'System.Guid',
                        'System.Int16',
                        'System.Int32',
                        'System.Int64',
                        'System.Single',
                        'System.UInt16',
                        'System.UInt32',
                        'System.UInt64')
                    
                    if ($types -contains $type)
                    {
                        return $type
                    }
                    else
                    {
                        return 'System.String'
                    }
                }
                
                $datatable = New-Object System.Data.DataTable
            }
            
            PROCESS
            
            {
                foreach ($object in $InputObject)
                {
                    $datarow = $datatable.NewRow()
                    foreach ($property in $object.PsObject.get_properties())
                    {
                        if ($datatable.Rows.Count -eq 0)
                        {
                            $column = New-Object System.Data.DataColumn
                            $column.ColumnName = $property.Name.ToString()
                            
                            if ($property.value)
                            {
                                if ($property.value -isnot [System.DBNull])
                                {
                                    $type = Get-Type $property.TypeNameOfValue
                                    $column.DataType = [System.Type]::GetType($type)
                                }
                            }
                            $datatable.Columns.Add($column)
                        }
                        if ($property.Gettype().IsArray)
                        {
                            $datarow.Item($property.Name) = $property.value | ConvertTo-XML -AS String -NoTypeInformation -Depth 1
                        }
                        else
                        {
                            if($property.value.length -gt 0)
                                {
                                    $datarow.Item($property.Name) = $property.value
                                }
                        }
                    }
                    $datatable.Rows.Add($datarow)
                }
            }
            
            End
            {
                return @( ,($datatable))
            }
            
        }        

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

$sql = "select agent_status=[dbo].[ufn_sqlwatch_get_agent_status]()"
$result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

if ($result.agent_status -eq $true) {

        Foreach ($job in $jobs) {

                $sql = "EXEC msdb.dbo.sp_update_job @job_name = N'$($job.name)', @enabled = 0;"
                Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
                }

        }

## custom pester scripts
Write-Output "Custom SqlWatch Tests"
$outputfile1 = "$ChecksFolder\Result.SqlWatch.Test.Checks.xml"
Invoke-Pester -Script @{
        Path=$CustomPesterChecksPath;
        Parameters=@{
                SqlInstance=$SqlInstance;
                SqlWatchDatabase=$SqlWatchDatabase;
                SqlWatchDatabaseTest=$SqlWatchDatabaseTest;
                MinSqlUpHours=$MinSqlUpHours;
                LookBackHours=$LookBackHours
            }
        } -OutputFormat  NUnitXml -OutputFile $outputfile1 -Show All 

## use dbachecks where possible and only build our own pester checks for things not already covered by dbachecks
Write-Output "dbachecks"
$outputfile2 = ("$ChecksFolder\Result.SqlWatch.DbaChecks.xml")
Invoke-DbcCheck -Check $Checks -SqlInstance $SqlInstance -Database $SqlWatchDatabase -OutputFormat  NUnitXml -OutputFile $outputfile2 -Show All 

#re-enable sqlwatch jobs:
if ($result.agent_status -eq $true) {

        Foreach ($job in $jobs) {
    
                $sql = "EXEC msdb.dbo.sp_update_job @job_name = N'$($job.name)', @enabled = 1;"
                Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            }

}


#cd C:\TEMP
#.\ReportUnit.exe $outputfile1
#.\ReportUnit.exe $outputfile2

$output = ParsePesterXML -XMLFile $outputfile2 -Server $SqlInstance | Out-DbaDataTable
Write-DbaDataTable -SqlInstance $SqlInstance -InputObject $output -Database $SqlWatchDatabaseTest -Schema tester -Table sqlwatch_pester_result

$output = ParsePesterXML -XMLFile $outputfile2 -Server $SqlInstance | Out-DbaDataTable
Write-DbaDataTable -SqlInstance $SqlInstance -InputObject $output -Database $SqlWatchDatabaseTest -Schema tester -Table sqlwatch_pester_result