CREATE FUNCTION [dbo].[ufn_sqlwatch_get_agent_status]
()
RETURNS bit
AS
BEGIN
	return (
		select case when (
			select count(*) 
			from master.dbo.sysprocesses 
			where program_name = N'SQLAgent - Generic Refresher'
			) > 0 
			then 1 
			else 0 end
		);
END
