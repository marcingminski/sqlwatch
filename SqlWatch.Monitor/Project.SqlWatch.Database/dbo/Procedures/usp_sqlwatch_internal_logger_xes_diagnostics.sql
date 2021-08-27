CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_xes_diagnostics]
	@data xml,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
AS
begin

	set nocount on;

	declare @target_data_char nvarchar(max),
			@target_data_xml xml,
			@max_event_time datetime,
		
			@execution_count bigint = 0,
			@session_name nvarchar(64) = 'system_health',
			@address varbinary(8),
			@filename varchar(8000),
			@store_event_data smallint = dbo.ufn_sqlwatch_get_config_value(23,null),
			@last_event_time datetime,

			@event_data utype_event_data;

	--bail out if this snapshot is set to not be collected:
	if (select collect 
		from [dbo].[sqlwatch_config_snapshot_type]
		where snapshot_type_id = @snapshot_type_id
		) = 0
		begin
			return;
		end;

		select @max_event_time = max(event_time) 
		from [dbo].[sqlwatch_logger_xes_query_processing]
		where sql_instance = @sql_instance;

		set @max_event_time = isnull(@max_event_time,'1970-01-01');

		with cte_query_processing as (
			select 
				[event_time] =  xed.event_data.value('(@timestamp)[1]', 'datetime'),
				[max_workers] = report_xml_node.value('(./@maxWorkers)[1]','bigint'),
				[workers_created] = report_xml_node.value('(./@workersCreated)[1]','bigint'),
				[idle_workers] = report_xml_node.value('(./@workersIdle)[1]','bigint'),
				[pending_tasks] = report_xml_node.value('(./@pendingTasks)[1]','bigint'),
				[unresolvable_deadlocks] = report_xml_node.value('(./@hasUnresolvableDeadlockOccurred)[1]','int'),
				[deadlocked_scheduler] = report_xml_node.value('(./@hasDeadlockedSchedulersOccurred)[1]','int'),
				[snapshot_time] = @snapshot_time,
				[snapshot_type_id] = @snapshot_type_id,
				[sql_instance] = @sql_instance
			from @data.nodes('/CollectionSnapshot/XesData/row/event_data/event') as xed(event_data)
			cross apply xed.event_data.nodes('./data[@name="data"]/value/queryProcessing') AS report_xml_nodes(report_xml_node)
		)
		insert into [dbo].[sqlwatch_logger_xes_query_processing](
				event_time
			, max_workers
			, workers_created
			, idle_workers
			, pending_tasks
			, unresolvable_deadlocks
			, deadlocked_scheduler
			, snapshot_time
			, snapshot_type_id
			, sql_instance
			)
		select 
			  [event_time]
			, [max_workers]
			, [workers_created]
			, [idle_workers]
			, [pending_tasks]
			, [unresolvable_deadlocks]
			, [deadlocked_scheduler]
			, [snapshot_time]
			, [snapshot_type_id]
			, [sql_instance]
		from cte_query_processing
		where event_time > @max_event_time
		option (maxdop 1, keepfixed plan);

		select @max_event_time = max(event_time) 
		from [dbo].[sqlwatch_logger_xes_iosubsystem]
		where sql_instance = @sql_instance;

		set @max_event_time = isnull(@max_event_time,'1970-01-01');

		with cte_io_subsystem as (
			select
				[event_time] = xed.event_data.value('(@timestamp)[1]', 'datetime'),
				[io_latch_timeouts] = report_xml_node.value('(./@ioLatchTimeouts)[1]','bigint'),
				[total_long_ios] = report_xml_node.value('(./@totalLongIos)[1]','bigint'),
				[longest_pending_request_file] = report_xml_node.value('(./longestPendingRequests/pendingRequest/@filePath)[1]','varchar(255)'),
				[longest_pending_request_duration] = report_xml_node.value('(./longestPendingRequests/pendingRequest/@duration)[1]','bigint'),
				[snapshot_time] = @snapshot_time,
				[snapshot_type_id] = @snapshot_type_id,
				[sql_instance] = @sql_instance
			from @data.nodes('/CollectionSnapshot/XesData/row/event_data/event') as xed(event_data)
			cross apply xed.event_data.nodes('./data[@name="data"]/value/ioSubsystem') AS report_xml_nodes(report_xml_node)
		)

		insert into [dbo].[sqlwatch_logger_xes_iosubsystem](
			  event_time
			, io_latch_timeouts
			, total_long_ios
			, longest_pending_request_file
			, longest_pending_request_duration
			, snapshot_time
			, snapshot_type_id
			, sql_instance
			)
		select 
			  [event_time]
			, [io_latch_timeouts]
			, [total_long_ios]
			, [longest_pending_request_file]
			, [longest_pending_request_duration]
			, [snapshot_time]
			, [snapshot_type_id] 
			, [sql_instance]
		from cte_io_subsystem
		where event_time > @max_event_time
		option (maxdop 1, keepfixed plan);
end;