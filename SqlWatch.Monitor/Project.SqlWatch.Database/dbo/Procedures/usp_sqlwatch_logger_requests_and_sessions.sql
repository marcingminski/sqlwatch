CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_requests_and_sessions]
as

declare @dummy int
	/*

	I am not entirely happy with this approach....

	declare @snapshot_type_id tinyint = 30,
			@date_snapshot_current datetime2(0),
			@sql_instance varchar(32) = dbo.ufn_sqlwatch_get_servername();

	declare @requests table (
		[session_id] [smallint] NOT NULL,
		[start_time] [datetime] NOT NULL,
		[status] [nvarchar](30) NOT NULL,
		[command] [nvarchar](32) NOT NULL,
		[sql_handle] [varbinary](64) NULL,
		[plan_handle] [varbinary](64) NULL,
		[database_name] [sysname] NOT NULL,
		[blocking_session_id] [smallint] NULL,
		[wait_type] [nvarchar](60) NULL,
		[wait_time] [int] NOT NULL,
		[text] [nvarchar](max) NULL,
		[program_name] [nvarchar](128) NULL,
		[client_interface_name] [nvarchar](32) NULL,
		[host_name] [nvarchar](128) NULL,
		[login_name] [nvarchar](128) NULL
	);

	insert into @requests
	select 
		session_id
		, start_time
		, status
		, command
		, sql_handle
		, plan_handle
		, sqlwatch_database_id
		, blocking_session_id
		, wait_type 
		, wait_time
	from sys.dm_exec_requests r
	
	inner join sys.databases db
	on db.database_id = r.database_id
	
	inner join dbo.sqlwatch_meta_database sdb
	on sdb.database_name = db.name
	and sdb.database_create_date = case when db.name = 'tempdb' then '1970-01-01' else db.create_date end

	;
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
	*/