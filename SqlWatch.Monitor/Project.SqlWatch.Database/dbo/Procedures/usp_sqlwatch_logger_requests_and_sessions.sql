CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_requests_and_sessions]
as

	declare @snapshot_type_id tinyint = 30,
			@date_snapshot_current datetime2(0),
			@sql_instance varchar(32) = dbo.ufn_sqlwatch_get_servername();

	exec [dbo].[usp_sqlwatch_internal_insert_header] 
		@snapshot_time_new = @date_snapshot_current OUTPUT,
		@snapshot_type_id = @snapshot_type_id;

	insert into [dbo].[sqlwatch_logger_dm_exec_requests]
	select 
		  er.session_id
		, er.start_time
		, er.status
		, er.command
		, sql_handle = null --er.sql_handle
		, plan_handle = null -- er.plan_handle
		, database_name = db.name
		, er.blocking_session_id
		, er.wait_type
		, er.wait_time
		, sql_text.text
		--, s.program_name
		--, s.client_interface_name
		--, s.host_name
		--, s.login_name
		, snapshot_time = @date_snapshot_current
		, snapshot_type_id = @snapshot_type_id
		, sql_instance = @sql_instance

	from sys.dm_exec_requests er (nolock)

	inner join sys.databases db (nolock)
		on db.database_id = er.database_id

	cross apply sys.dm_exec_sql_text (er.plan_handle) sql_text
	
	where er.session_id > 50
	option (keep plan);

	insert into [dbo].[sqlwatch_logger_dm_exec_sessions]
	select
		  session_id
		, login_time
		, host_name
		, program_name
		, client_interface_name
		, login_name
		, status
		, cpu_time
		, memory_usage
		, total_scheduled_time
		, total_elapsed_time
		, last_request_start_time
		, last_request_end_time
		, reads
		, writes
		, logical_reads
		, database_name = db.name

		, snapshot_time = @date_snapshot_current
		, snapshot_type_id = @snapshot_type_id
		, sql_instance = @sql_instance
	from sys.dm_exec_sessions s

	left join sys.databases db
	on s.database_id = db.database_id
	where session_id > 50
	option (keep plan);
