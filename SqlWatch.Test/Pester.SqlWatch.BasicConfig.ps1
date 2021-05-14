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

New-SqlWatchTestDatabase
New-SqlWatchTest

Describe "$($SqlInstance): System Configuration" -Tag 'System' {

    $configuration = Get-SqlConfiguration

    If ($configuration.SqlServerCollation -eq $configuration.SqlWatchCollation) {
        $Skip = $true
    } else {
        $Skip = $false
    }
    
    It 'The SQLWATCH database collaction should be different to system collaction to incrase test coverage' -Skip:$Skip {}         
  
    if ($configuration.SqlServerUptimeHours -lt 168) {
        $Skip = $true 
    } else { 
        $Skip = $false 
    }

    It 'SQL Server should be running for at least a week to test data retention routines' -Skip:$Skip {}

    if ($configuration.UTCOffset -ge 0) { 
        $Skip = $true 
    } else { 
        $Skip = $false 
    }

    #if the local time is ahead of utc we can easily spot records in the future.
    #cannot do the same when the local time is behind or same as utc.
    It 'The Servers local time should be ahead of UTC in order to test that we are only using UTC dates' -Skip {}

}