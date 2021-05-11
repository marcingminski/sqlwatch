CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_get_xes_data]
	@session_name nvarchar(64),
	@object_name nvarchar(256) = null,
	@min_interval_s int = 1,
	@last_event_time datetime = null --to be removed
AS

set nocount on;

declare @results table (
	event_data xml,
	object_name nvarchar(256),
	event_time datetime
);

if [dbo].[ufn_sqlwatch_get_product_version]('major') < 11
	begin
		exec [dbo].[usp_sqlwatch_internal_log]
			@proc_id = @@PROCID,
			@process_stage = '56FE7588-B8F4-49C5-A40D-167AC6067919',
			@process_message = 'Product version must be 11 or higher to use Extended Events',
			@process_message_type = 'WARNING';

		--we havve to return empty resultset back to the caller:
		select event_data, object_name, event_time
		from @results;

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
		@address varbinary(8),
		@event_file  varchar(128),
		@xes_current_last_event_time datetime;
		
select @xes_last_captured_execution_count = execution_count
	,  @xes_last_captured_event_time = isnull(last_event_time,'1970-01-01')
from [dbo].[sqlwatch_stage_xes_exec_count]
where session_name = @session_name
option (keep plan);

--bail out if we're checking too often:
if datediff(second,@xes_last_captured_event_time,getutcdate()) < @min_interval_s
	begin
		select event_data, object_name, event_time
		from @results;

		return;
	end;

--we're getting session address in a separate batch
--becuase when we join xe_sessions with xe_session_targets
--the execution goes up to 500ms. two batches run in 4 ms.
select @address = address 
from sys.dm_xe_sessions with (nolock)
where name = @session_name
option (keepfixed plan);

--having it all in a single place will improve performance and allow getting rid of some of the user functions:
select 
		@xes_current_execution_count = isnull(execution_count,0)
	,	@event_file = convert(xml,[target_data]).value('(/EventFileTarget/File/@name)[1]', 'varchar(8000)')
from sys.dm_xe_session_targets with (nolock)
where event_session_address = @address
and target_name = 'event_file'
option (keepfixed plan);

--bail out if the xes has not triggered since last run:
if (@xes_current_execution_count <= @xes_last_captured_execution_count)
	begin
		select event_data, object_name, event_time
		from @results;
		return;
	end;

with cte_event_data as (
	select 
		  event_data=convert(xml,event_data)
		, t.object_name
		, event_time = [dbo].[ufn_sqlwatch_get_xes_timestamp]( event_data )
	from sys.fn_xe_file_target_read_file (@event_file, null, null, null) t
	where @object_name is null 
		or (
			@object_name is not null 
			and object_name = @object_name
			)
)
insert into @results
select event_data, object_name, event_time
from cte_event_data
where event_time > @xes_last_captured_event_time;

--get last event_time:
select @xes_current_last_event_time = max(event_time)
from @results;

--update execution count:
update [dbo].[sqlwatch_stage_xes_exec_count]
set  execution_count = @xes_current_execution_count
	, last_event_time = isnull(@xes_current_last_event_time,getutcdate())
where session_name = @session_name
option (keep plan);

--return data:
select event_data, object_name, event_time
from @results;