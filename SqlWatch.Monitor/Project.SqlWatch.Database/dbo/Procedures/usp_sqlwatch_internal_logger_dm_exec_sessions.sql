CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_dm_exec_sessions]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
as
begin
	set nocount on;

	insert into [dbo].[sqlwatch_logger_dm_exec_sessions_stats] (
		[type]
		,running
		,sleeping
		,dormant
		,preconnect
		,cpu_time
		,reads
		,writes
		,memory_usage
		,snapshot_time
		,snapshot_type_id
		,sql_instance
	)
	select
		[type] = is_user_process
		,[running] = isnull(convert(real,sum(case when isnull(status,'') collate database_default = 'Running' and session_id <> @@SPID then 1 else 0 end)),0)
		,[sleeping] = isnull(convert(real,sum(case when isnull(status,'') collate database_default = 'Sleeping' then 1 else 0 end)),0)
		,[dormant] = isnull(convert(real,sum(case when isnull(status,'') collate database_default = 'Dormant' then 1 else 0 end)),0)
		,[preconnect] = isnull(convert(real,sum(case when isnull(status,'') collate database_default = 'Preconnect' then 1 else 0 end)),0)
		,[cpu_time] = isnull(sum(convert(real,cpu_time)),0)
		,[reads] = isnull(sum(convert(real,reads)),0)
		,[writes] = isnull(sum(convert(real,writes)),0)
		,[memory_usage] = isnull(sum(convert(real,memory_usage)),0)
		,snapshot_time = @snapshot_time
		,snapshot_type_id = @snapshot_type_id
		,sql_instance = @sql_instance
	from openxml (@xdoc, '/CollectionSnapshot/dm_exec_sessions/row',1) 
		with (
			session_id int,
			status nvarchar(30),
			is_user_process bit,
			cpu_time int,
			reads bigint,
			writes bigint,
			memory_usage int
		)	
	group by is_user_process
	option (maxdop 1, keep plan);
end;