CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_tester]
	@test_name varchar(128)
AS

set nocount on;

-- simple procedure to replace Pester tests
-- since testing database involves running T-SQL against tables, there's not to involve PowrShell as we may as well write T-SQL in the procedure
-- this procedure will also serve as a "health check" to check that SQLWATCH is running OK.

declare @sql nvarchar(max) = ''

------------------------------------------------------------------------------------
-- test blocking
------------------------------------------------------------------------------------
if @test_name in ('All', 'Blocking') 
	begin
		--first, check that we have blocking threshold set:
		if (select convert(int,value_in_use) from sys.configurations where name = 'blocked process threshold (s)') > 15
			begin
				raiserror ('Blocking Process Threshold is not enabled',10,0) with nowait
				return
			end

		--we need a new test database as SQLWATCH db has RCSI enabled which prevents blocking
		raiserror ('Creating test database',10,0) with nowait
		set @sql = 'create database SQLWATCH_BLOCKING_TEST;'
		exec sp_executesql @sql;

		--set db snapshot to not RCIS in case model is set to RCSI:
		raiserror ('Setting new database options',10,0) with nowait
		set @sql = 'ALTER DATABASE [SQLWATCH_BLOCKING_TEST] SET READ_COMMITTED_SNAPSHOT OFF
		ALTER DATABASE [SQLWATCH_BLOCKING_TEST] SET RECOVERY SIMPLE ;'
		exec sp_executesql @sql;
		
		--create sample table:
		raiserror ('Creating sample tables',10,0) with nowait
		set @sql = 'create table [SQLWATCH_BLOCKING_TEST].dbo.sqlwatch_test_blocking (colA int);
		insert into [SQLWATCH_BLOCKING_TEST].dbo.sqlwatch_test_blocking (colA)
		values (1);'
		exec sp_executesql @sql;

		--blocking can only happen when another session tries to access blocked object.
		--sql cannot do this on its own in a single procedure:
		raiserror ('Runnig Blocking transaction for 45 seconds',10,0) with nowait
		raiserror ('Run this manually in separate sessions (SSMS tabs) to cause blocking: 
		select * from [SQLWATCH_BLOCKING_TEST].dbo.sqlwatch_test_blocking
		',10,1) with nowait

		--create blocking now:
		set @sql = '
		begin tran
		select * from [SQLWATCH_BLOCKING_TEST].dbo.sqlwatch_test_blocking with (tablock, holdlock, xlock)
		waitfor delay ''00:00:45''
		commit tran
		waitfor delay ''00:00:10'''
		exec sp_executesql @sql;

		--drop database:
		raiserror ('Cleaning up',10,0) with nowait
		EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'SQLWATCH_BLOCKING_TEST'
		set @sql = 'USE [master];
		ALTER DATABASE [SQLWATCH_BLOCKING_TEST] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE;
		DROP DATABASE [SQLWATCH_BLOCKING_TEST];'
		exec sp_executesql @sql;

	end