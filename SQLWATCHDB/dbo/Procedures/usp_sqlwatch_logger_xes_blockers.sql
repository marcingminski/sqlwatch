CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_xes_blockers]
AS

if [dbo].[ufn_sqlwatch_get_product_version]('major') >= 11
	begin
		/* for this to work you must enable blocked process monitor */
		--inspired by and based on Michael J Stewart http://michaeljswart.com/2016/02/look-at-blocked-process-reports-collected-with-extended-events/

		declare @snapshot_time datetime = getutcdate()
		declare @snapshot_type_id tinyint = 9
		declare @filename varchar(8000)

		insert into dbo.[sqlwatch_logger_snapshot_header] (snapshot_time, snapshot_type_id)
		select @snapshot_time, @snapshot_type_id

		select cast(target_data as xml) AS target_data
		into #xes
		from sys.dm_xe_session_targets xet
		inner join sys.dm_xe_sessions xes
			on xes.address = xet.event_session_address
		/* this will dynamically set session so the user has a choice to either use system_health session ot SQLWATCH_*. 
			if SQLWATCH session is switched off we will use system_health otherwise use SQLWATCH_* */
		where xes.name = isnull((select name from sys.dm_xe_sessions where name = 'SQLWATCH_blockers'),'system_health')
			and xet.target_name = 'ring_buffer'

		insert into [dbo].[sqlwatch_logger_xes_blockers](
			attach_activity_id, attach_activity_sequence,
			blocking_start_time, blocking_end_time,
			blocked_ecid, blocked_spid, blocked_sql,
			[database_name], lock_mode, 
			blocking_ecid, blocking_spid, blocking_sql, 
			blocking_duration_ms, [blocking_client_app_name], [blocking_client_hostname],
			report_xml,
			snapshot_time, snapshot_type_id
		)
		select attach_activity_id, attach_activity_sequence,
			blocking_start_time, blocking_end_time,
			blocked_ecid, blocked_spid, blocked_sql,
			[database name], lock_mode, 
			blocking_ecid, blocking_spid, blocking_sql, 
			blocking_duration_ms, [blocking_client app name], [blocking_client hostname],
			report_xml,
			@snapshot_time, @snapshot_type_id
		from (
			select 
				 [attach_activity_id]=substring(bps.[attach_activity_id],1,len(bps.[attach_activity_id])-charindex('-',reverse(bps.[attach_activity_id]))) 
				,[attach_activity_sequence]=right(bps.[attach_activity_id],charindex('-',reverse(bps.[attach_activity_id]))-1)
				,blocking_start_time = dateadd(ms,-bps.[blocking_duration_ms],bps.[report_end_time])
				,blocking_end_time=bps.[report_end_time]
				,bps.blocked_ecid
				,bps.blocked_spid
				,bps.blocked_sql
				,bps.[database name]
				,bps.[lock_mode]
				,bps.blocking_ecid
				,bps.blocking_spid
				,bps.blocking_sql
				,bps.[blocking_duration_ms]
				,bps.[blocking_client app name]
				,bps.[blocking_client hostname]
				,bps.report_xml
				/* SQL starts logging blocking chains as soon as they reach thresholds and NOT once the blocking chain has finished
					this means we are going to get multiple entries per each chain until it has finished. we can go ahead and remove any previous
					records of the same chain */
				,session_blocking_sequence = row_number() over (partition by convert(datetime2(0),dateadd(ms,-bps.[blocking_duration_ms],bps.[report_end_time]))
																							, bps.blocked_spid
																							, bps.[database name]
																							, bps.blocking_spid
																							, bps.[blocking_client app name]
																							, bps.[blocking_client hostname] 
																					order by bps.[blocking_duration_ms] desc)
			from #xes xet
			--from sys.dm_xe_session_targets xet with (nolock)
			--inner join sys.dm_xe_sessions xes with (nolock)
			--	on xes.address = xet.event_session_address
			--	/*  this will dynamically set session so the user has a choice to either use system_health session ot SQLWATCH_*. 
			--		if SQLWATCH session is switched off we will use system_health otherwise use SQLWATCH_* */
			--	and xes.name = isnull((select name from sys.dm_xe_sessions where name = 'SQLWATCH_blockers'),'system_health')
			--	and xet.target_name = 'ring_buffer'
			--from sys.fn_xe_file_target_read_file(@filename, null, null, null) xet
			cross apply ( select cast(xet.target_data as xml) ) AS target_data ([xml])
			cross apply target_data.[xml].nodes('/RingBufferTarget/event[@name="blocked_process_report"]') AS bp_nodes(bp_node)
			cross apply bp_node.nodes('./data[@name="blocked_process"]/value/blocked-process-report') AS bp_report_xml_nodes(bp_report_xml_node)
			cross apply
				(
					select 
					 [report_xml] = cast(bp_report_xml_node.query('.') as xml)
					,[report_end_time] = bp_node.value('(./@timestamp)[1]', 'datetime')
					,[monitor_loop] = bp_report_xml_node.value('(//@monitorLoop)[1]', 'nvarchar(100)')
					,[blocked_spid] = bp_report_xml_node.value('(./blocked-process/process/@spid)[1]', 'int')
					,[blocked_ecid] = bp_report_xml_node.value('(./blocked-process/process/@ecid)[1]', 'int')
					,[blocked_sql] = bp_report_xml_node.value('(./blocked-process/process/inputbuf)[1]', 'nvarchar(max)')
					,[client app name] = bp_node.value('(./action[@name="client app name"]/value)[1]', 'nvarchar(128)')
					,[database name] = nullif(bp_node.value('(./data[@name="database_name"]/value)[1]', 'nvarchar(128)'),'')
					,[lock_mode]=bp_node.value('(./data[@name="lock_mode"]/text)[1]', 'varchar(50)')
					,[blocking_spid] = bp_report_xml_node.value('(./blocking-process/process/@spid)[1]', 'int')
					,[blocking_ecid] = bp_report_xml_node.value('(./blocking-process/process/@ecid)[1]', 'int')
					,[blocking_sql] = bp_report_xml_node.value('(./blocking-process/process/inputbuf)[1]', 'varchar(max)')
					,[blocking_duration_ms] = bp_node.value('(./data[@name="duration"]/value)[1]', 'bigint')/1000
					,[blocking_username]=bp_report_xml_node.value('(./action[@name="username"]/value)[1]', 'nvarchar(128)')
					,[blocking_client app name] = bp_report_xml_node.value('(./blocking-process/process/@clientapp)[1]', 'nvarchar(128)')
					,[blocking_client hostname] = bp_report_xml_node.value('(./blocking-process/process/@hostname)[1]', 'nvarchar(128)')
					,[attach_activity_id] = bp_node.value('(./action[@name="attach_activity_id"]/value )[1]', 'varchar(255)')
				) AS bps
			left join [dbo].[sqlwatch_logger_xes_blockers] t
				on t.attach_activity_id = substring(bps.[attach_activity_id],1,len(bps.[attach_activity_id])-charindex('-',reverse(bps.[attach_activity_id]))) 
				and t.attach_activity_sequence = right(bps.[attach_activity_id],charindex('-',reverse(bps.[attach_activity_id]))-1)
			where t.attach_activity_id is null
		) t
		where session_blocking_sequence = 1
		option (maxdop 1);
	end
else
	print 'Product version must be 11 or higher'