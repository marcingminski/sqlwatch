CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_xes_diagnostics]
AS

set xact_abort on

if [dbo].[ufn_sqlwatch_get_product_version]('major') >= 11
	begin
		declare @snapshot_time datetime,
				@snapshot_type_id tinyint = 10,
				@filename varchar(8000),
				@target_data_char nvarchar(max),
				@target_data_xml xml,
				@utc_offset_minute int = [dbo].[ufn_sqlwatch_get_server_utc_offset]('MINUTE')

		/* using file target instead of ring buffer to have more resilient source as ring buffer can drop events if there are many */
		select @filename= [dbo].[ufn_sqlwatch_get_xes_target_file] ('system_health')

		select cast(event_data as xml) AS target_data
		into #t
		from sys.fn_xe_file_target_read_file(@filename, null, null, null) xet
		where object_name = 'sp_server_diagnostics_component_result'

		exec [dbo].[usp_sqlwatch_internal_insert_header] 
			@snapshot_time_new = @snapshot_time OUTPUT,
			@snapshot_type_id = @snapshot_type_id

		begin tran

			insert into [dbo].[sqlwatch_logger_xes_query_processing](event_time, max_workers, workers_created, idle_workers, pending_tasks
				, unresolvable_deadlocks, deadlocked_scheduler, snapshot_time, snapshot_type_id
			)
			select 
				[event_time] = dateadd(minute,@utc_offset_minute,xml_node.value('(./@timestamp)[1]','datetime')),
				[max_workers] = report_xml_node.value('(./@maxWorkers)[1]','bigint'),
				[workers_created] = report_xml_node.value('(./@workersCreated)[1]','bigint'),
				[idle_workers] = report_xml_node.value('(./@workersIdle)[1]','bigint'),
				[pending_tasks] = report_xml_node.value('(./@pendingTasks)[1]','bigint'),
				[unresolvable_deadlocks] = report_xml_node.value('(./@hasUnresolvableDeadlockOccurred)[1]','int'),
				[deadlocked_scheduler] = report_xml_node.value('(./@hasDeadlockedSchedulersOccurred)[1]','int'),
				[snapshot_time] = @snapshot_time,
				[snapshot_type_id] = @snapshot_type_id
			--from sys.fn_xe_file_target_read_file(@filename, null, null, null) xet
			from #t xet
			cross apply ( select cast(xet.target_data as xml) ) AS target_data ([xml])
			cross apply target_data.[xml].nodes('/event[@name="sp_server_diagnostics_component_result"]') AS xml_nodes(xml_node)
			cross apply xml_node.nodes('./data[@name="data"]/value/queryProcessing') AS report_xml_nodes(report_xml_node)
			where xml_node.value('(./@timestamp)[1]','datetime') > (select isnull(max(event_time),'1970-01-01') from [dbo].[sqlwatch_logger_xes_query_processing])
			--and xet.object_name = 'sp_server_diagnostics_component_result'
			option (maxdop 1);

			insert into [dbo].[sqlwatch_logger_xes_iosubsystem](event_time, io_latch_timeouts, total_long_ios, longest_pending_request_file, longest_pending_request_duration,
				snapshot_time, snapshot_type_id
			)
			select
				[event_time] = xml_node.value('(./@timestamp)[1]','datetime'),
				[io_latch_timeouts] = report_xml_node.value('(./@ioLatchTimeouts)[1]','bigint'),
				[total_long_ios] = report_xml_node.value('(./@totalLongIos)[1]','bigint'),
				[longest_pending_request_file] = report_xml_node.value('(./longestPendingRequests/pendingRequest/@filePath)[1]','varchar(255)'),
				[longest_pending_request_duration] = report_xml_node.value('(./longestPendingRequests/pendingRequest/@duration)[1]','bigint'),
				[snapshot_time] = @snapshot_time,
				[snapshot_type_id] = @snapshot_type_id
			--from sys.fn_xe_file_target_read_file(@filename, null, null, null) xet
			from #t xet
			cross apply ( select cast(xet.target_data as xml) ) AS target_data ([xml])
			cross apply target_data.[xml].nodes('/event[@name="sp_server_diagnostics_component_result"]') AS xml_nodes(xml_node)
			cross apply xml_node.nodes('./data[@name="data"]/value/ioSubsystem') AS report_xml_nodes(report_xml_node)
			where xml_node.value('(./@timestamp)[1]','datetime') > (select isnull(max(event_time),'1970-01-01') from [dbo].[sqlwatch_logger_xes_iosubsystem])
			--and xet.object_name = 'sp_server_diagnostics_component_result'
			option (maxdop 1);

		commit tran
	end
