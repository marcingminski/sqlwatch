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

Describe "$($SqlInstance): Database Design" -Tag 'DatabaseDesign' {    

    Context 'Tables have Primary Keys' {
        It 'Table <_.TableName> has Primary Key' -ForEach $(Get-SqlWatchTablePKeys) {

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
        It 'Table <_.TableName> has (<_.FkCount>) Foreign Keys' -ForEach $(Get-SqlWatchTableFKeys) {

            If (
                ( $($_.TableName) -Like "dbo.sqlwatch_config*" -and $($_.FkCount) -eq 0) `
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
                $($_.FkCount) | Should -BeGreaterThan 0
            }
        }        
    }

    Context 'Check Constraints are trusted' {
        It 'Check Constraint <_.ConstraintName> is trusted' -ForEach $(Get-CheckConstraints) {
            $($_.IsNotTrusted) | Should -Be 0 
        }
    }    

    Context 'Default Constraints are named' {
        It 'Default Constraint <_.ConstraintName> is named' -ForEach $(Get-DefaultConstraints) {
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
            $result = Invoke-SqlWatchCmd -Query $sql;
                       
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

    Context 'Parent objects contain SQLWATCH keyword' {
        It 'Object <_.ObjectName> contains the SQLWATCH keywors' -ForEach $(Get-AllParentObjects) {
            if (
                $($_.ObjectName) -eq '__RefactorLog' `
            -or $($_.ObjectName) -eq 'dbachecksChecks' `
            -or $($_.ObjectName) -eq 'dbachecksResults' `
            ) {
                Set-ItResult -Skip -Because 'it is a third party table'
            }  
            $($_.ObjectName) | Should -BeLike '*sqlwatch*' -Because "We should be able to identify all SQLWATCH objects when deploying into a third party database"
        }
    }

    Context 'Procedures should have the correct prefix' {
        It 'Procedure <_.ProcedureName> has the correct prefix' -ForEach $(Get-AllProcedures) {
            $($_.ProcedureName) | Should -BeLike 'usp_*'
        }
    }

    Context 'Functions should have the correct prefix' {
        It 'Function <_.FunctionName> has the correct prefix' -ForEach $(Get-AllFunctions) {
            $($_.FunctionName) | Should -BeLike 'ufn_*'
        }
    }    

    Context 'Views should have the correct prefix' {
        It 'View <_.ViewName> has the correct prefix' -ForEach $(Get-AllViews) {
            $($_.ViewName) | Should -BeLike 'vw_*'
        }
    }        

    Context 'Tables should have the correct prefix' {

        It 'Table <_.TableName> has the correct prefix' -ForEach $(Get-AllTables) {
            if (
                $($_.TableName) -eq '__RefactorLog' `
            -or $($_.TableName) -eq 'dbachecksChecks' `
            -or $($_.TableName) -eq 'dbachecksResults' `
            ) {
                Set-ItResult -Skip -Because 'it is a third party table'
            }            
            $($_.TableName) | Should -BeLike 'sqlwatch_*'
        }
    }    
    
    Context 'Foreign Keys should have the correct prefix' {
        It 'Foreign Key <_.FkName> has the correct prefix' -ForEach $(Get-ForeignKeys) {
            $($_.FkName) | Should -BeLike 'fk_*'
        }
    }

    Context 'Primary Keys should have the correct prefix' {
        It 'Primary Key <_.PkName> has the correct prefix' -ForEach $(Get-PrimaryKeys) {
            $($_.PkName) | Should -BeLike 'pk_*'
        }
    }   
}