CREATE FUNCTION [dbo].[ufn_sqlwatch_get_xes_target_file]
(
	@session_name varchar(255)
)
returns varchar(255)
as
begin
		return (select convert(xml,[target_data]).value('(/EventFileTarget/File/@name)[1]', 'varchar(8000)')
				from sys.dm_xe_session_targets
				where [target_name] = 'event_file' 
				and [event_session_address] = (
					select [address]
					from sys.dm_xe_sessions 
					where [name] = @session_name
					)
			)
end