/* 
   https://github.com/marcingminski/sqlwatch/issues/29
   To persist data integrity it has to be done in one transaction
   We are doing this manually because we are reducing the lenght of the column and
   it would be seen as potential data loss and would stop automated deployment.

   As a workaround, we could enable data loss deployment in the dacpac but
   I feel safer mitigating the scope of potential loss and doing it manually.
   
   -------------------------------------------------------------------
   Preparations:
    1. Disable and stop ALL SQLWATCH jobs.
	2. Run the below BEFORE upgrading to 1.7.7054.2196
	3. Upgrade database to 1.7.7054.2196
	4. Re-enable ALL SQLWATCH jobs.

*/

set xact_abort on;

/* new table names */
if (select CHARACTER_MAXIMUM_LENGTH from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME = 'sqlwatch_logger_perf_os_performance_counters'
and COLUMN_NAME = 'object_name') <> 128
and (select CHARACTER_MAXIMUM_LENGTH from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME = 'sqlwatch_logger_perf_os_performance_counters'
and COLUMN_NAME = 'instance_name') <> 128
and (select CHARACTER_MAXIMUM_LENGTH from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME = 'sqlwatch_logger_perf_os_performance_counters'
and COLUMN_NAME = 'counter_name') <> 128
	begin
		begin tran datatypemigration
		alter table [dbo].[sqlwatch_logger_perf_os_performance_counters] drop constraint [pk_sql_perf_mon_perf_counters];
		alter table [dbo].[sqlwatch_logger_perf_os_performance_counters] alter column [performance_counter_id] nvarchar(128) not null;
		alter table [dbo].[sqlwatch_logger_perf_os_performance_counters] alter column [instance_name] nvarchar(128) not null;
		alter table [dbo].[sqlwatch_logger_perf_os_performance_counters] alter column [counter_name] nvarchar(128) not null;
		commit tran datatypemigration
	end
GO

/* old table names */
if (select CHARACTER_MAXIMUM_LENGTH from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME = 'sql_perf_mon_perf_counters'
and COLUMN_NAME = 'object_name') <> 128
and (select CHARACTER_MAXIMUM_LENGTH from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME = 'sql_perf_mon_perf_counters'
and COLUMN_NAME = 'instance_name') <> 128
and (select CHARACTER_MAXIMUM_LENGTH from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME = 'sql_perf_mon_perf_counters'
and COLUMN_NAME = 'counter_name') <> 128
	begin
		begin tran datatypemigration
		alter table [dbo].sql_perf_mon_perf_counters drop constraint [pk_sql_perf_mon_perf_counters];
		alter table [dbo].sql_perf_mon_perf_counters alter column [object_name] nvarchar(128) not null;
		alter table [dbo].sql_perf_mon_perf_counters alter column [instance_name] nvarchar(128) not null;
		alter table [dbo].sql_perf_mon_perf_counters alter column [counter_name] nvarchar(128) not null;
		commit tran datatypemigration
	end
GO

--dacpac will recreate required Primary Key