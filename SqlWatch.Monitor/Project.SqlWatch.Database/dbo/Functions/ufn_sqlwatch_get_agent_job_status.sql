CREATE FUNCTION [dbo].[ufn_sqlwatch_get_agent_job_status]
(
	@job_name sysname
)
RETURNS smallint
AS
BEGIN
	declare @status smallint

	--does the job exist?
	select @status = enabled
	from msdb.dbo.sysjobs
	where name = @job_name;

	if @status is null
		begin
			set @status = -1;
		end;

	return @status;
END
