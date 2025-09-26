CREATE FUNCTION [dbo].[ufn_sqlwatch_parse_xes_event_data](@event_data xml) 
RETURNS @retEventData TABLE
(
	duration bigint,
	cpu_time bigint,
	physical_reads bigint,
	logical_reads bigint,
	writes bigint,
	row_count bigint,
	last_row_count bigint,
	line_number int,
	offset int,
	offset_end int,
	sql_text varchar(max),
	client_app_name varchar(max),
	client_hostname varchar(max),
	database_name varchar(max),
	plan_handle varchar(max),
	session_id varchar(max),
	username varchar(max)

) with schemabinding
AS
BEGIN
	insert @retEventData
	select 
		@event_data.value('(event/data[@name="duration"]/value)[1]', 'bigint') as Duration,
		@event_data.value('(event/data[@name="cpu_time"]/value)[1]', 'bigint') as cpu_time,
		@event_data.value('(event/data[@name="physical_reads"]/value)[1]', 'bigint') as physical_reads,
		@event_data.value('(event/data[@name="logical_reads"]/value)[1]', 'bigint') as logical_reads,
		@event_data.value('(event/data[@name="writes"]/value)[1]', 'bigint') as writes,
		@event_data.value('(event/data[@name="row_count"]/value)[1]', 'bigint') as row_count,
		@event_data.value('(event/data[@name="last_row_count"]/value)[1]', 'bigint') as last_row_count,
		@event_data.value('(event/data[@name="line_number"]/value)[1]', 'int') as line_number,
		@event_data.value('(event/data[@name="offset"]/value)[1]', 'int') as offset,
		@event_data.value('(event/data[@name="offset_end"]/value)[1]', 'int') as offset_end,
		dbo.ufn_sqlwatch_clean_sql_text(@event_data.value('(event/action[@name="sql_text"]/value)[1]', 'varchar(max)')) as sql_text,
		@event_data.value('(event/action[@name="client_app_name"]/value)[1]', 'varchar(max)') as client_app_name,
		@event_data.value('(event/action[@name="client_hostname"]/value)[1]', 'varchar(max)') as client_hostname,
		@event_data.value('(event/action[@name="database_name"]/value)[1]', 'varchar(max)') as [database_name],
		convert(varbinary(64),'0x' + @event_data.value('(action[@name="plan_handle"]/value)[1]', 'varchar(max)'),1) as plan_handle,
		@event_data.value('(event/action[@name="session_id"]/value)[1]', 'int') as session_id,
		@event_data.value('(event/action[@name="username"]/value)[1]', 'varchar(max)') as username;

	RETURN;
END;
