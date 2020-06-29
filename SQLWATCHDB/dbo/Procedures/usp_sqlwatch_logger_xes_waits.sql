CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_xes_waits]
AS

set nocount on

if [dbo].[ufn_sqlwatch_get_product_version]('major') >= 11
	begin
		declare @snapshot_time datetime2(0),
				@snapshot_type_id tinyint = 6,
				@utc_offset_minute int = [dbo].[ufn_sqlwatch_get_server_utc_offset]('MINUTE')

		declare @event_data table (event_data xml)

		insert into @event_data
		select cast(event_data as xml)
		from sys.fn_xe_file_target_read_file ('SQLWATCH_waits*.xel', null, null, null) t

		set xact_abort on
		begin transaction

		exec [dbo].[usp_sqlwatch_internal_insert_header] 
			@snapshot_time_new = @snapshot_time OUTPUT,
			@snapshot_type_id = @snapshot_type_id

			;with cte_xes_waits as (
				select
					[event_time] = dateadd(minute,@utc_offset_minute,xed.event_data.value('(@timestamp)[1]', 'datetime')),
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
			from @event_data t
				cross apply t.event_data.nodes('event') as xed (event_data)
			)
			insert into [dbo].[sqlwatch_logger_xes_waits_stats] (event_time, wait_type_id, [event_name], duration, signal_duration, username, tx.sql_text, session_id, database_name,
				client_hostname, client_app_name, activity_id, activity_sequence, [activity_id_xfer], [activity_seqeuence_xfer], snapshot_time, snapshot_type_id)
			select tx.event_time, mws.wait_type_id, tx.[event_name], tx.duration, tx.signal_duration, tx.username, tx.sql_text, tx.session_id, tx.database_name,
				tx.client_hostname, tx.client_app_name
				, [activity_id]=substring(tx.[activity_id],1,len(tx.[activity_id])-charindex('-',reverse(tx.[activity_id]))) 
				, [activity_sequence]=right(tx.[activity_id],charindex('-',reverse(tx.[activity_id]))-1)
				, [activity_id_xfer]=substring(tx.[activity_id_xfer],1,len(tx.[activity_id_xfer])-charindex('-',reverse(tx.[activity_id_xfer]))) 
				, [activity_seqeuence_xfer]=right(tx.[activity_id_xfer],charindex('-',reverse(tx.[activity_id_xfer]))-1)
				, tx.snapshot_time, tx.snapshot_type_id
			from cte_xes_waits tx
			left join [dbo].[sqlwatch_meta_wait_stats] mws
				on mws.sql_instance = @@SERVERNAME
				and mws.wait_type = tx.wait_type
			left join [dbo].[sqlwatch_logger_xes_waits_stats] x
				on x.activity_id = substring(tx.[activity_id],1,len(tx.[activity_id])-charindex('-',reverse(tx.[activity_id]))) 
				and x.activity_sequence = right(tx.[activity_id],charindex('-',reverse(tx.[activity_id]))-1)
			where x.activity_id is null
			and tx.event_name = 'wait_info'
			--option (maxdop 1);

		commit tran
	end
else
	print 'Product version must be 11 or higher'

