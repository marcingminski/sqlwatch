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

$TestDatabaseName = New-TestDatabase
$global:SqlWatchDatabaseTest=$TestDatabaseName

Describe "$($SqlInstance): Application Log Errors" -Tag 'ApplicationErrors' {

    $SqlWatchErrors = Get-SqlWatchAppLogErrorsDuringTest

    if ($SqlWatchErrors.Count -eq 0 -eq $null) {
        It 'Application Log should not contain ERRORS Raised during the testing'{}
    } else {

        It 'Procedure <_.ERROR_PROCEDURE> has raised an error' -ForEach $SqlWatchErrors {
            $($_.ERROR_MESSAGE) | Should -BeNullOrEmpty
        }
    }   
}