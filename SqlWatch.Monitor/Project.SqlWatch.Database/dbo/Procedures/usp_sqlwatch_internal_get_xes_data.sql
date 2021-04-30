CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_get_xes_data]
	@session_name nvarchar(64),
	@last_event_time datetime
AS
	declare @event_file  varchar(128);
	set @event_file = @session_name + '*.xel';

	set @last_event_time = case when @last_event_time is null then '1970-01-01' else @last_event_time end;

	with cte_event_data as (
		select 
			  event_data=convert(xml,event_data)
			, object_name
			, event_time = [dbo].[ufn_sqlwatch_get_xes_timestamp]( event_data )
		from sys.fn_xe_file_target_read_file (@event_file, null, null, null) t
	)
	select event_data, object_name, event_time
	from cte_event_data
	-- get only new events. This results in much smaller xml to parse in the steps below and dramatically speeds up the query
	where event_time >= @last_event_time;