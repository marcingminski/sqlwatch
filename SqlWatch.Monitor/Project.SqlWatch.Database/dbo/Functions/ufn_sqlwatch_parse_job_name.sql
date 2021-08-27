CREATE FUNCTION [dbo].[ufn_sqlwatch_parse_job_name]
(
	@client_app_name nvarchar(128),
	@job_name nvarchar(128) = null,
	@sql_instance varchar(32) = null
)
RETURNS nvarchar(128) 
AS
/* 
	this function will parse the agent job name and replace the binary string:
		(SQLAgent - TSQL JobStep (Job 0x583FB91A7B48A64E96B7FDDEBDC58EC0 : Step 1)) 
	with the actual job name:
		(SQLAgent - TSQL JobStep (Job SQLWATCH-SAMPLE-JOB : Step 1)) 
*/
BEGIN
	if @job_name is null
		begin
			declare @job_id uniqueidentifier = [dbo].[ufn_sqlwatch_parse_job_id] (@client_app_name);

			if @sql_instance is null
				begin
					set @sql_instance = @@SERVERNAME;
				end;

			select 
				@job_name = job_name
			from dbo.sqlwatch_meta_agent_job (nolock)
			where sql_instance = @sql_instance
			and job_id = @job_id;
		end

	RETURN (
		select case 
			when @client_app_name like 'SQLAGent - TSQL JobStep%' and @job_name is not null
			then replace(@client_app_name collate DATABASE_DEFAULT,left(replace(@client_app_name collate DATABASE_DEFAULT,'SQLAgent - TSQL JobStep (Job ',''),34),@job_name) 
			else @client_app_name
			end
			);
END;
