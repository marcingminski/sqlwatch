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
$global:OutputSqlErrors=$false

Describe "$($SqlInstance): Database Design" -Tag 'DatabaseDesign' {    

    Context 'Tables have Primary Keys' {

        It 'Table <_.TableName> has Primary Key' -ForEach $(Get-SqlWatchTableKeys) {

            If (
                $($TableName) -eq "dbo.sqlwatch_pester_result" `
            -or $($TableName) -eq "dbo.dbachecksChecks" `
            -or $($TableName) -eq "dbo.dbachecksResults") {
                Set-ItResult -Skip -Because 'it is a third party table'
            } else {
                $PkName | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Tables have Foreign Keys' {

        It 'Table <_.TableName> has Foreign Key' -ForEach $(Get-SqlWatchTableKeys) {

            If (
                $($_.TableName) -Like "dbo.sqlwatch_config*" `
            -or $($_.TableName) -Like "dbo.sqlwatch_stage*" `
            -or $($_.TableName) -Like "dbo.sqlwatch_app_version"
                ) {
                Set-ItResult -Skip -Because 'it does not have FK by design'
            }
            ElseIf (
                $($_.TableName) -eq "dbo.sqlwatch_pester_result" `
            -or $($_.TableName) -eq "dbo.dbachecksChecks" `
            -or $($_.TableName) -eq "dbo.dbachecksResults" `
            -or $($_.TableName) -eq "dbo.__RefactorLog"  
            ) {
                Set-ItResult -Skip -Because 'it is a third party table'
            } else {
                $($_.FkName) | Should -Not -BeNullOrEmpty
            }
        }        
    }

    Context 'Check Constraints are trusted' {

        It 'Check Constraint <_.ConstraintName> is trusted' -ForEach $(Get-CheckConstraints) {
            $($_.IsNotTrusted) | Should -Be 0 
        }
    }    

    Context 'Default Constraints are named' {

        It 'Default Constraint <_.ConstraintName> is named' -ForEach $(Get-CheckConstraints) {
            $_.ConstraintName | Should -Not -BeLike "DF__*"
        }
    }
    
    Context 'Foreign Keys are trusted' {

        It 'Foreign key <_.FkName> is trusted' -ForEach $(Get-ForeignKeys) {
            $($_.IsNotTrusted) | Should -Be 0 
        }
    }
    
    Context 'Dates are correct' {

        It 'Datetime values in <_.SqlWatchTable>.<_.SqlWatchColumn> are not in the future' -ForEach $(Get-DateTimeColumns) {

            $sql = "select [value]=isnull(max($($_.SqlWatchColumn)),'') from $($_.SqlWatchTable) where $($_.SqlWatchColumn) is not null";
            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql;
                       
            if ($result.value -eq $null) {
                Set-ItResult -Skip -Because 'value is empty'
            } 
            
            if ($_.SqlWatchColumn -eq "valid_until") {
                Set-ItResult -Skip -Because 'this column should only hold future dates'
            }

            if ($_.SqlWatchColumn -eq "report_time") {
                Set-ItResult -Skip -Because 'it contains rounded up values which may render the date to be in the future'
            }            
            
            $result.value | Should -Not -BeGreaterThan $(Get-Date) -Because 'Values in the future could indicate that we are collecting local time rather than UTC'  
        }
    }
}