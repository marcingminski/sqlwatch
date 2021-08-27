CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_get_data_xes]
	@session_name nvarchar(64),
	@object_name nvarchar(256) = null,
	@min_interval_s int = 1,
	@snapshot_time datetime2(0) = null,
	@snapshot_type_id tinyint = null,
	@event_data_xml_out xml output
AS
begin

	set nocount on;

	declare @results table (
		event_data xml,
		object_name nvarchar(256),
		event_time datetime2(3),
		file_offset bigint
	);


	if [dbo].[ufn_sqlwatch_get_product_version]('major') < 11
		begin
			raiserror('Product version must be 11 or higher to use Extended Events',16,1);
			return;
		end;

	--The execution count is per session, not per session's object_name.
	--This means that we may still run the collector because the session has trigger but it has not logged our particular object.
	--This is clearly visible in the system_health where session triggers roughly even 1 minute but the sp_server_diagnostics_component_result object 
	--is only logged every 5 minutes. I have added a parameter @min_interval_s that we can pass to skip the collector if the data diff is less.
	--Ideally we shuold just schdule the collector to run less often
	declare @xes_last_captured_execution_count bigint,
			@xes_current_execution_count bigint,
			@xes_last_captured_event_time datetime,
			@xes_current_address varbinary(8),
			@event_file nvarchar(600),
			@event_file_name nvarchar(260),
			@event_file_path nvarchar(260),
			@xes_current_last_event_time datetime,
			@event_data xml,
			@stage_session_name nvarchar(64),
			@xes_last_captured_address varbinary(8),
			@xes_last_captured_file_name nvarchar(260),
			@xes_last_offset bigint,
			@xes_current_offset bigint,
			@xes_address varbinary(8),
			@xes_last_captured_file_path nvarchar(260),
			@event_session_detail_hash varbinary(16),
			@xes_file nvarchar(260),
			@runcount int = 0,
			@last_check datetime2(0),
			@xes_last_check datetime2(0),
			@rows_retrieved int

			;
		
	beginning:

	set @runcount = @runcount + 1;

	select 
		@xes_address = event_session_address,
		@xes_last_captured_execution_count = execution_count,
		@xes_file = event_session_file,
		@xes_last_offset = event_session_file_offset,

		--if no previous captures, we are going to ignore history and start from last 15 minutes
		--to force-load all historical data from xml we'd have to set the last_event_time manually in the table.
		--this is important for system sessions that may have lots of data in them before installing SQLWATCH.
		--processing all this data at once could cause timeouts. We are just going to monitor from when SQLWATCH was installed by default.
		@xes_last_captured_event_time = isnull(last_event_time,dateadd(minute,-15,getutcdate())),
		@stage_session_name = session_name,
		@last_check = last_retrieved_from_file_time
	from [dbo].[sqlwatch_stage_xes_exec_count]
	where session_name = @session_name
	option (keep plan);


	select 
			@xes_current_execution_count = isnull(execution_count,0)
		,	@event_file = convert(xml,[target_data]).value('(/EventFileTarget/File/@name)[1]', 'varchar(8000)')
	from sys.dm_xe_session_targets with (nolock)
	where event_session_address = @xes_address
	and target_name = 'event_file'
	option (keepfixed plan);

	if @event_file is null --have we got the wrong address?
		begin
			select @xes_address = address 
			from sys.dm_xe_sessions with (nolock)
			where name = @session_name;

			if @xes_address is null
				begin
					declare @error_message varchar(1024);
					set @error_message = FORMATMESSAGE('The session %s does not exist.',@session_name);
					raiserror(@error_message, 16, 1);
					return;
				end;

			update dbo.sqlwatch_stage_xes_exec_count
				set event_session_address = @xes_address
				where session_name = @session_name;


			if @runcount > 1
				begin
					--now return empy set so we can exit. we are going to pick up the data in the next run.
					--otherwise we'd have to use goto to re-run the code but there a risk of continous loop if event session doesnt run.
					insert into @results (event_data, object_name, event_time, file_offset)
					select event_data = null, object_name = null, event_time = null, file_offset = null;
				end
			else
				begin
					goto beginning;
				end;

		end;

	if isnull(@xes_file,'') != @event_file
		begin
			--the file name has changed
			update dbo.sqlwatch_stage_xes_exec_count
				set execution_count = 0,
					last_event_time = null,
					event_session_file_offset = null,
					event_session_file = @event_file,
					last_file_change = getutcdate()
				where session_name = @session_name;

			if @runcount > 2
				begin
					--now return empy set so we can exit. we are going to pick up the data in the next run.
					insert into @results (event_data, object_name, event_time, file_offset)
					select event_data = null, object_name = null, event_time = null, file_offset = null;
				end
			else
				begin
					goto beginning;
				end;

		end

	--return data:
	if @xes_current_execution_count > @xes_last_captured_execution_count
		begin
			set @xes_last_check = getutcdate();

			--the offset value must match the actual offset in the given file.
			--the file, and the offset value must make a valid pair. we cannot give a null or 0 offset whilst giving a file
			--therefore, we must null out file_name if offset is null. this will trigger essentially a full load.

			if @xes_last_offset is null
				begin
					set @event_file_name = null;
				end
			else
				begin
					set @event_file_name = @event_file;
				end;


			with cte_event_data as (
				select 
						event_data=convert(xml,event_data)
					, t.object_name
					, event_time = [dbo].[ufn_sqlwatch_get_xes_timestamp]( event_data )
					, file_offset
				from sys.fn_xe_file_target_read_file (@event_file, null, @event_file_name, @xes_last_offset) t
				where @object_name is null 
					or (
						@object_name is not null 
						and object_name = @object_name
						)
			)
			insert into @results (event_data, object_name, event_time, file_offset)
			select event_data, object_name, event_time, file_offset
			from cte_event_data
			where event_time > @xes_last_captured_event_time;

			set @rows_retrieved = @@ROWCOUNT;

		end
	else
		begin
			insert into @results (event_data, object_name, event_time, file_offset)
			select event_data = null, object_name = null, event_time = null, file_offset = null;
		end;



	select @event_data_xml_out = (
			select snapshot_header = (
				select
				  sql_instance = @@SERVERNAME
				, snapshot_time = GETUTCDATE()
				, session_name = @session_name	
				, snapshot_type_id = @snapshot_type_id
				for xml raw, type
			)
			, (
				select 
					  object_name
					, event_data
				from @results
				for xml path ('row'), root('XesData'), ELEMENTS XSINIL, type	
			)
			for xml path ('CollectionSnapshot')
	);

	select 
		@xes_current_last_event_time = max(event_time),
		@xes_current_offset = max(file_offset)
	from @results;

	if @xes_current_execution_count > @xes_last_captured_execution_count 
		or @xes_current_last_event_time > @xes_last_captured_event_time
		or @stage_session_name is null
		or isnull(@xes_last_check,'1970-01-01') > isnull(@last_check,'1970-01-01')
		begin
			merge [dbo].[sqlwatch_stage_xes_exec_count] as target
			using (
				select  session_name = @session_name
						,last_event_time = @xes_current_last_event_time
						,execution_count = @xes_current_execution_count
						,event_session_file_offset = @xes_current_offset
						,event_session_address = @xes_address
						,event_session_file = @event_file
				) as source	
			on source.session_name = target.session_name collate database_default

			when matched then update
				set	  execution_count = source.execution_count 
					, last_event_time = source.last_event_time 
					, event_session_address = source.event_session_address
					, event_session_file_offset = source.event_session_file_offset
					, event_session_file = source.event_session_file
					, last_retrieved_from_file_time = @xes_last_check
					, last_retrieved_from_file_rowcount = @rows_retrieved

			when not matched then
				insert (session_name, execution_count, last_event_time, event_session_address, event_session_file, last_retrieved_from_file_time, last_retrieved_from_file_rowcount)
				values (source.session_name, 0, null, source.event_session_address, source.event_session_file, @xes_last_check, @rows_retrieved);
		end;

end;