--DIRABLE SQLWATCH-LOGGER-PERFORMANCE JOB BEFORE RUNNING THIS SCRIPT AND RE-ENABLE AFTER THE DEPLOYMENT!!!

set xact_abort on
begin tran fred

	create table [dbo].[sqlwatch_meta_wait_stats]
	(
		[sql_instance] varchar(32) not null,
		[wait_type] nvarchar(60) not null, 
		[wait_type_id] smallint identity (-32768,1) not null,
		constraint pk_sqlwatch_meta_wait_stats primary key (
			[sql_instance], [wait_type]
			)
	)

	insert into [dbo].[sqlwatch_meta_wait_stats] ([sql_instance], [wait_type])
	select distinct @@SERVERNAME, dm.[wait_type]
	from sys.dm_os_wait_stats dm
	left join [dbo].[sqlwatch_meta_wait_stats] ws
		on ws.[sql_instance] = @@SERVERNAME
		and ws.[wait_type] = dm.[wait_type] collate database_default
	where ws.[wait_type] is null

	select ws.[wait_type_id], wait_type_id, 
		waiting_tasks_count, wait_time_ms, max_wait_time_ms, signal_wait_time_ms, snapshot_time, snapshot_type_id, ws.sql_instance
	into #sqlwatch_logger_perf_os_wait_stats
	from [dbo].[sqlwatch_logger_perf_os_wait_stats] ws
				inner join [dbo].[sqlwatch_meta_wait_stats] ms
				on ms.sql_instance = ws.sql_instance
				and ms.wait_type = ws.[wait_type_id]

	delete from [dbo].[sqlwatch_logger_perf_os_wait_stats]

	insert into [dbo].[sqlwatch_logger_perf_os_wait_stats]
	select  wait_type_id, 
		waiting_tasks_count, wait_time_ms, max_wait_time_ms, signal_wait_time_ms, snapshot_time, snapshot_type_id, sql_instance
	from #sqlwatch_logger_perf_os_wait_stats

	alter table [dbo].[sqlwatch_logger_perf_os_wait_stats] drop constraint [pk_sql_perf_mon_wait_stats] with ( ONLINE = OFF )
	drop index [idx_sqlwatch_wait_stats_001] on [dbo].[sqlwatch_logger_perf_os_wait_stats]

	alter table [dbo].[sqlwatch_logger_perf_os_wait_stats] alter column [wait_type_id] smallint not null

	--correct indexes and constraints will be recreated during deployment

commit tran fred