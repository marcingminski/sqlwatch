CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_xes_blockers_and_deadlocks]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
AS
begin
	set nocount on;

	declare @execution_count bigint = 0,
			@session_name nvarchar(64) = 'SQLWATCH_Blockers',
			@filename varchar(8000);


	--quit if the collector is switched off
	if (select collect 
		from [dbo].[sqlwatch_config_snapshot_type]
		where snapshot_type_id = @snapshot_type_id
		) = 0
		begin
			return;
		end;

	--warn if blocked proces monitor is disabled
	if (select convert(int,value_in_use) 
		from sys.configurations
		where name = 'blocked process threshold (s)'
		) = 0
		begin
			declare @error_message nvarchar(max) = 'Blocked process monitor is disabled, blocking chains will not be captured. To enable capturing blocking chains please you have to enable Blocked Process Monitor in Sql Server. You can it by running: You can do it by running exec [dbo].[usp_sqlwatch_config_sqlserver_set_blocked_proc_threshold] @threshold_seconds = 5.
Read more: https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/blocked-process-threshold-server-configuration-option';

            exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
				@proc_id = @@PROCID,
				@process_stage = '1D88C464-6874-4F23-A1AF-1B7850BCCA4B',
				@process_message = @error_message,
				@process_message_type = 'WARNING',
                @message_payload = null;
		end;


	/*  For this to work you must enable blocked process monitor */

	/*  The below code, whilst not directly copied, is inspired by and based on Michael J Stewart blocked process report.
		I have learned how to approach this problem from Michael's blog. Please add his blog to your favourites as its a really good SQL Server Knowledgebase.

		http://michaeljswart.com/2016/02/look-at-blocked-process-reports-collected-with-extended-events/
		https://github.com/mjswart/sqlblockedprocesses licensed under MIT
		https://github.com/mjswart/sqlblockedprocesses/blob/master/LICENSE

		MIT License

		Copyright (c) 2018 mjswart

		Permission is hereby granted, free of charge, to any person obtaining a copy
		of this software and associated documentation files (the "Software"), to deal
		in the Software without restriction, including without limitation the rights
		to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
		copies of the Software, and to permit persons to whom the Software is
		furnished to do so, subject to the following conditions:

		The above copyright notice and this permission notice shall be included in all
		copies or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
		IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
		FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
		AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
		LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
		OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
		SOFTWARE.	
				
	*/
				
		select 
			x.[event_time]
			, x.[activity_id]
			, x.[monitor_loop]
			, [duration] = x.[duration] * 1.0 / 1000.0 -- microsec to ms
			, x.[lock_mode]
			, x.[transaction_name]
			, x.[blocked_spid]
			, x.[blocked_ecid]
			, [blocked_clientapp] = [dbo].[ufn_sqlwatch_parse_job_name](x.[blocked_clientapp], null, @sql_instance)
			, x.[blocked_currentdbname]
			, x.[blocked_hostname]
			, x.[blocked_loginname]
			, x.[blocked_inputbuff]
			, x.[blocking_spid]
			, x.[blocking_ecid]
			, [blocking_clientapp] = [dbo].[ufn_sqlwatch_parse_job_name](x.[blocking_clientapp],null, @sql_instance)
			, x.[blocking_currentdbname]
			, x.[blocking_hostname]
			, x.[blocking_loginname]
			, x.[blocking_inputbuff]
			, x.[bp_report_xml]
			, x.deadlock_report_xml
			, x.object_name
			, x.blocked_process_id
			, RN = ROW_NUMBER() over (partition by x.blocked_process_id, x.blocked_spid, x.blocked_ecid, x.blocking_spid, x.blocking_ecid order by x.event_time desc)
		into #t
		from openxml(@xdoc, '/CollectionSnapshot/XesData/row/event_data/event',1)
			with (
				object_name varchar(128) '../../object_name',
				event_time datetime '@timestamp',
				activity_id varchar(128) 'action[@name="attach_activity_id"]',
				monitor_loop int 'data[@name="blocked_process"]//blocked-process-report/@monitorLoop',
				duration bigint 'data[@name="duration"]',
				lock_mode nvarchar(50) 'data[@name="blocked_process"]//blocked-process-report/blocked-process/process/@lockMode',
				transaction_name nvarchar(128) 'data[@name="blocked_process"]//blocked-process-report/blocked-process/process/@transactionname',
				
				blocked_spid int 'data[@name="blocked_process"]//blocked-process-report/blocked-process/process/@spid',
				blocked_ecid int 'data[@name="blocked_process"]//blocked-process-report/blocked-process/process/@ecid',
				blocked_clientapp nvarchar(128) 'data[@name="blocked_process"]//blocked-process-report/blocked-process/process/@clientapp',
				blocked_currentdbname nvarchar(128) 'data[@name="blocked_process"]//blocked-process-report/blocked-process/process/@currentdbname',
				blocked_hostname nvarchar(128) 'data[@name="blocked_process"]//blocked-process-report/blocked-process/process/@hostname',
				blocked_loginname nvarchar(128) 'data[@name="blocked_process"]//blocked-process-report/blocked-process/process/@loginname',
				blocked_inputbuff nvarchar(max) 'data[@name="blocked_process"]//blocked-process-report/blocked-process/process/inputbuff',

				blocking_spid int 'data[@name="blocked_process"]//blocked-process-report/blocking-process/process/@spid',
				blocking_ecid int 'data[@name="blocked_process"]//blocked-process-report/blocking-process/process/@ecid',
				blocking_clientapp nvarchar(128) 'data[@name="blocked_process"]//blocked-process-report/blocking-process/process/@clientapp',
				blocking_currentdbname nvarchar(128) 'data[@name="blocked_process"]//blocked-process-report/blocking-process/process/@currentdbname',
				blocking_hostname nvarchar(128) 'data[@name="blocked_process"]//blocked-process-report/blocking-process/process/@hostname',
				blocking_loginname nvarchar(128) 'data[@name="blocked_process"]//blocked-process-report/blocking-process/process/@loginname',
				blocking_inputbuff nvarchar(max) 'data[@name="blocked_process"]//blocked-process-report/blocking-process/process/inputbuf',

				bp_report_xml xml 'data[@name="blocked_process"]//blocked-process-report',
				deadlock_report_xml xml 'data[@name="xml_report"]//deadlock',

				blocked_process_id varchar(256)  'data[@name="blocked_process"]//blocked-process-report/blocked-process/process/@id'
			) x;


		merge dbo.sqlwatch_logger_xes_blockers as target
		using (

			select 
				x.[event_time]
				, x.[activity_id]
				, x.[monitor_loop]
				, x.[duration] 
				, x.[lock_mode]
				, x.[transaction_name]
				, x.[blocked_spid]
				, x.[blocked_ecid]
				, [blocked_clientapp] = [dbo].[ufn_sqlwatch_parse_job_name](x.[blocked_clientapp], null, @sql_instance)
				, x.[blocked_currentdbname]
				, x.[blocked_hostname]
				, x.[blocked_loginname]
				, x.[blocked_inputbuff]
				, x.[blocking_spid]
				, x.[blocking_ecid]
				, [blocking_clientapp] = [dbo].[ufn_sqlwatch_parse_job_name](x.[blocking_clientapp],null, @sql_instance)
				, x.[blocking_currentdbname]
				, x.[blocking_hostname]
				, x.[blocking_loginname]
				, x.[blocking_inputbuff]
				, x.[bp_report_xml]

				, snapshot_time = @snapshot_time
				, snapshot_type_id = @snapshot_type_id
				, sql_instance = @sql_instance 

				, blocking_start_time = convert(datetime2(0),dateadd(ms,-x.[duration],x.[event_time]))
				, x.blocked_process_id

			from #t x

			left join dbo.sqlwatch_logger_xes_blockers b
				on b.activity_id = x.activity_id
				and b.sql_instance = @sql_instance
				and b.snapshot_type_id = @snapshot_type_id
				and b.event_time = x.event_time
				and b.monitor_loop = x.monitor_loop

			where b.activity_id is null
			and x.object_name = 'blocked_process_report'
			and x.RN = 1

		)as source

		on source.blocked_process_id = target.blocked_process_id
		and source.blocked_spid = target.blocked_spid
		and source.blocked_ecid = target.blocked_ecid
		and source.blocking_spid = target.blocking_spid
		and source.blocking_ecid = target.blocking_ecid
		and source.blocking_start_time = target.blocking_start_time
		and source.sql_instance = target.sql_instance
		and source.snapshot_type_id = target.snapshot_type_id

		when matched then
			update set [blocking_duration_ms] = source.[duration],
				event_time = source.event_time,
				snapshot_time = source.snapshot_time,
				instance_count = isnull(instance_count,0) + 1
		when not matched then
			insert (
				[event_time]
				, activity_id
				, [monitor_loop]
				, [blocking_duration_ms]
				, [lock_mode]
				, transaction_name

				, [blocked_spid]
				, [blocked_ecid]
				, [blocked_clientapp]
				, [blocked_currentdbname]
				, [blocked_hostname]
				, [blocked_loginname]
				, [blocked_inputbuff]

				, [blocking_spid]
				, [blocking_ecid]
				, [blocking_clientapp]
				, [blocking_currentdbname]
				, [blocking_hostname]
				, [blocking_loginname]
				, [blocking_inputbuff]
				
				, [report_xml]
				, [snapshot_time]
				, snapshot_type_id
				, sql_instance

				, blocking_start_time
				, blocked_process_id
				, instance_count
				)
			values (
				  source.[event_time]
				, source.[activity_id]
				, source.[monitor_loop]
				, source.[duration] 
				, source.[lock_mode]
				, source.[transaction_name]
				, source.[blocked_spid]
				, source.[blocked_ecid]
				, source.[blocked_clientapp] 
				, source.[blocked_currentdbname]
				, source.[blocked_hostname]
				, source.[blocked_loginname]
				, source.[blocked_inputbuff]
				, source.[blocking_spid]
				, source.[blocking_ecid]
				, source.[blocking_clientapp] 
				, source.[blocking_currentdbname]
				, source.[blocking_hostname]
				, source.[blocking_loginname]
				, source.[blocking_inputbuff]
				, source.[bp_report_xml]


				, source.snapshot_time 
				, source.snapshot_type_id 
				, source.sql_instance  
				, source.blocking_start_time 
				, source.blocked_process_id			
				, 1
			)
			;

		--insert into dbo.sqlwatch_logger_xes_blockers (
		--		[event_time]
		--		, activity_id
		--		, [monitor_loop]
		--		, [blocking_duration_ms]
		--		, [lock_mode]
		--		, transaction_name

		--		, [blocked_spid]
		--		, [blocked_ecid]
		--		, [blocked_clientapp]
		--		, [blocked_currentdbname]
		--		, [blocked_hostname]
		--		, [blocked_loginname]
		--		, [blocked_inputbuff]

		--		, [blocking_spid]
		--		, [blocking_ecid]
		--		, [blocking_clientapp]
		--		, [blocking_currentdbname]
		--		, [blocking_hostname]
		--		, [blocking_loginname]
		--		, [blocking_inputbuff]
				
		--		, [report_xml]
		--		, [snapshot_time]
		--		, snapshot_type_id
		--		, sql_instance

		--		, blocking_start_time
		--		, blocked_process_id
		--)
		--select 
		--	x.[event_time]
		--	, x.[activity_id]
		--	, x.[monitor_loop]
		--	, x.[duration] 
		--	, x.[lock_mode]
		--	, x.[transaction_name]
		--	, x.[blocked_spid]
		--	, x.[blocked_ecid]
		--	, [blocked_clientapp] = [dbo].[ufn_sqlwatch_parse_job_name](x.[blocked_clientapp], null, @sql_instance)
		--	, x.[blocked_currentdbname]
		--	, x.[blocked_hostname]
		--	, x.[blocked_loginname]
		--	, x.[blocked_inputbuff]
		--	, x.[blocking_spid]
		--	, x.[blocking_ecid]
		--	, [blocking_clientapp] = [dbo].[ufn_sqlwatch_parse_job_name](x.[blocking_clientapp],null, @sql_instance)
		--	, x.[blocking_currentdbname]
		--	, x.[blocking_hostname]
		--	, x.[blocking_loginname]
		--	, x.[blocking_inputbuff]
		--	, x.[bp_report_xml]


		--	, snapshot_time = @snapshot_time
		--	, snapshot_type_id = @snapshot_type_id
		--	, sql_instance = @sql_instance 

		--	, blocking_start_time = dateadd(ms,-x.[duration],x.[event_time])
		--	, x.blocked_process_id

		--from #t x

		--left join dbo.sqlwatch_logger_xes_blockers b
		--	on b.activity_id = x.activity_id
		--	and b.sql_instance = @sql_instance
		--	and b.snapshot_type_id = @snapshot_type_id
		--	and b.event_time = x.event_time
		--	and b.monitor_loop = x.monitor_loop

		--where b.activity_id is null
		--and x.object_name = 'blocked_process_report';

		--- dump deadlocks xml into a table:
		insert into dbo.sqlwatch_logger_xes_deadlocks (
			[snapshot_time] ,
			[snapshot_type_id] ,
			[sql_instance] ,
			[activity_id] ,
			[event_time] ,
			[xml_report]
		)
			select 
			snapshot_time = @snapshot_time,
			snapshot_type_id = @snapshot_type_id,
			sql_instance = @sql_instance,
			activity_id,
			event_time,
			deadlock_report_xml
			from #t
			where object_name = 'xml_deadlock_report';

end;
