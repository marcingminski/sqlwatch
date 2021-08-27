CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_broker_activated_actions_queue]
as
begin
	declare @job_name nvarchar(128),
			@job_status tinyint,
			@job_id uniqueidentifier,
			@process_message nvarchar(2000)
			;

	set @job_name = case when DB_NAME() <> 'SQLWATCH' then 'SQLWATCH-[' + DB_NAME() + ']-PROCESS-ACTIONS' else 'SQLWATCH-[' + DB_NAME() + ']-PROCESS-ACTIONS' end;

	select 
		@job_status = enabled,
		@job_id = job_id
	from msdb.dbo.sysjobs
	where name = @job_name;

	if @job_status = 1 
		begin
			if not exists ( 
				select 1 
				from msdb.dbo.sysjobactivity a  with (nolock)
				where a.job_id = @job_id
				and a.run_requested_date is not null
				and a.stop_execution_date is null
			) 
			begin
				exec msdb.dbo.sp_start_job @job_name = @job_name;
			end;
		end
	else
		begin
			set @process_message = FORMATMESSAGE('The job responsible for processing actions (%s) is disabled. Actions will not be processed. If you do not want to process actions, please disable the action itslef, otherwise the queue will be filling up becuase there is nothing to clear the queue.',@job_name);

            exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
				@proc_id = @@PROCID,
				@process_stage = '42C07F6F-BFF7-44F9-BB41-CF23F0969FF3',
				@process_message = @process_message ,
				@process_message_type = 'ERROR'
		end;
end;