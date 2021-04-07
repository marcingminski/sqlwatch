CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_dm_exec_requests]
as

	declare @snapshot_type_id tinyint = 30,
			@date_snapshot_current datetime2(0)

	exec [dbo].[usp_sqlwatch_internal_insert_header] 
		@snapshot_time_new = @date_snapshot_current OUTPUT,
		@snapshot_type_id = @snapshot_type_id;

	insert into [dbo].[sqlwatch_logger_dm_exec_requests]
	select 
		  er.session_id
		, er.start_time
		, er.status
		, er.command
		, er.sql_handle
		, er.plan_handle
		, database_name = db.name
		, er.blocking_session_id
		, er.wait_type
		, er.wait_time
		, sql_text.text
		, s.program_name
		, s.client_interface_name
		, s.host_name
		, s.login_name
		, snapshot_time = @date_snapshot_current
		, snapshot_type_id = @snapshot_type_id
		, sql_instance = dbo.ufn_sqlwatch_get_servername()

	from sys.dm_exec_requests er (nolock)
		inner join sys.databases db (nolock)
		on db.database_id = er.database_id

		left join sys.dm_exec_sessions s (nolock)
		on s.session_id = er.session_id
	cross apply sys.dm_exec_sql_text (er.plan_handle) sql_text
	where er.session_id > 50
	and er.session_id <> @@SPID
	and wait_time > 0
	and s.cpu_time > 0