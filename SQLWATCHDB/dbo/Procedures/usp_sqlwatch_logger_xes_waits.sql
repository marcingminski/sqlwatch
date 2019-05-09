CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_xes_waits]
AS

set xact_abort on
begin tran

if [dbo].[ufn_sqlwatch_get_product_version]('major') >= 11
	begin
		declare @snapshot_time datetime = getutcdate()
		declare @snapshot_type_id tinyint

		select cast(target_data as xml) AS targetdata
		into #xes
		from sys.dm_xe_session_targets xet
		inner join sys.dm_xe_sessions xes
			on xes.address = xet.event_session_address
		/* this will dynamically set session so the user has a choice to either use system_health session ot SQLWATCH_*. 
			if SQLWATCH session is switched off we will use system_health otherwise use SQLWATCH_* */
		where xes.name = isnull((select name from sys.dm_xe_sessions where name = 'SQLWATCH_waits'),'system_health')
			and xet.target_name = 'ring_buffer'

		--------------------------------------------------------------------------------------------------------------------------------
		-- waits
		--------------------------------------------------------------------------------------------------------------------------------
		set @snapshot_type_id = 6
		insert into dbo.[sqlwatch_logger_snapshot_header] (snapshot_time, snapshot_type_id)
		select @snapshot_time, @snapshot_type_id

		;with cte_xes_waits as (
			select
				[event_time] = xed.event_data.value('(@timestamp)[1]', 'datetime'),
				[wait_type] = xed.event_data.value('(data[@name="wait_type"]/text)[1]', 'varchar(255)'),
				[event_name]=xed.event_data.value('(@name)[1]', 'varchar(255)'),
				[duration] = xed.event_data.value('(data[@name="duration"]/value)[1]', 'bigint'),
				[signal_duration] = xed.event_data.value('(data[@name="signal_duration"]/value)[1]', 'bigint'),
				[username] = xed.event_data.value('(action[@name="username"]/value)[1]', 'varchar(255)'),
				[sql_text] = xed.event_data.value('(action[@name="sql_text"]/value)[1]', 'varchar(max)'),
				[session_id] = xed.event_data.value('(action[@name="session_id"]/value)[1]', 'int'),
				[database_name] = xed.event_data.value('(action[@name="database_name"]/value)[1]', 'varchar(255)'),
				[client_hostname] = xed.event_data.value('(action[@name="client_hostname"]/value)[1]', 'varchar(255)'),
				[client_app_name] = xed.event_data.value('(action[@name="client_app_name"]/value)[1]', 'varchar(255)'),
				[activity_id] = xed.event_data.value('(action[@name="attach_activity_id"]/value)[1]', 'varchar(255)'),
				[activity_id_xfer] = xed.event_data.value('(action[@name="attach_activity_id_xfer"]/value)[1]', 'varchar(255)'),
				[snapshot_time] = @snapshot_time,
				[snapshot_type_id] = @snapshot_type_id
			from #xes t
				cross apply targetdata.nodes('//RingBufferTarget/event') AS xed (event_data)
			--where xed.event_data.value('(@name)[1]', 'varchar(255)') in ('wait_info','wait_info_external')
		)
		insert into [dbo].[sqlwatch_logger_xes_waits_stats] (event_time, wait_type, [event_name], duration, signal_duration, username, sql_text, session_id, database_name,
			client_hostname, client_app_name, activity_id, activity_sequence, [activity_id_xfer], [activity_seqeuence_xfer], snapshot_time, snapshot_type_id)
		select tx.event_time, tx.wait_type, tx.[event_name], tx.duration, tx.signal_duration, tx.username, tx.sql_text, tx.session_id, tx.database_name,
			tx.client_hostname, tx.client_app_name
			, [activity_id]=substring(tx.[activity_id],1,len(tx.[activity_id])-charindex('-',reverse(tx.[activity_id]))) 
			, [activity_sequence]=right(tx.[activity_id],charindex('-',reverse(tx.[activity_id]))-1)
			, [activity_id_xfer]=substring(tx.[activity_id_xfer],1,len(tx.[activity_id_xfer])-charindex('-',reverse(tx.[activity_id_xfer]))) 
			, [activity_seqeuence_xfer]=right(tx.[activity_id_xfer],charindex('-',reverse(tx.[activity_id_xfer]))-1)
			, tx.snapshot_time, tx.snapshot_type_id
		from cte_xes_waits tx
		left join [dbo].[sqlwatch_logger_xes_waits_stats] x
			on x.activity_id = substring(tx.[activity_id],1,len(tx.[activity_id])-charindex('-',reverse(tx.[activity_id]))) 
			and x.activity_sequence = right(tx.[activity_id],charindex('-',reverse(tx.[activity_id]))-1)
		where x.activity_id is null
		and tx.event_name = 'wait_info'
		option (maxdop 1);

	end
else
	print 'Product version must be 11 or higher'

commit tran