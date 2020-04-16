CREATE PROCEDURE [dbo].[usp_sqlwatch_repository_remote_table_import]
as

/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	[usp_sqlwatch_repository_remote_table_import]

 Description:
	Central Repository procedure. Imports tables from remote SQLWATCH via linked server.

 Parameters
	N/A

 Author:
	Marcin Gminski

 Change Log:
	1.0		2020-xx-xx	- Marcin Gminski, Initial version
	1.1		2020-04-16	- Marcin Gminski, fixed error when running procedure manually not via agnt
-------------------------------------------------------------------------------------------------------------------
*/


set nocount on;
set xact_abort on; 

declare @sql_instance varchar(32),
		@object_name nvarchar(512),
		@load_type char(1),
		@sql nvarchar(max),
		@sql_remote nvarchar(max),
		@snapshot_time_start datetime2(0),
		@snapshot_time_end datetime2(0),
		@snapshot_type_id tinyint,
		@ls_server nvarchar(128),

		@join_keys nvarchar(max),
		@has_identity bit = 0,
		@table_name nvarchar(128),
		@table_schema nvarchar(128),
		@all_columns nvarchar(max),
		@pk_columns nvarchar(max),
		@nonpk_columns nvarchar(max),
		@has_errors bit = 0,
		@message nvarchar(max),
		@rmtq_timestart datetime2(7),
		@rmtq_timeend datetime2(7),
		@rowcount_imported bigint,
		@rowcount_loaded bigint,
		@database varchar(256),
		@object_name_t nvarchar(512),
		@thread_name nvarchar(max),
		@thread_spid nvarchar(max)

/* try obtain the agent job name that is running this particular thread */
select	@thread_name = j.name,
		@thread_spid = '(spid: ' + convert(varchar(10),p.spid) + ')'
		from master.dbo.sysprocesses p
		inner join msdb.dbo.sysjobs j
		on master.dbo.fn_varbintohexstr(convert(varbinary(16), job_id)) COLLATE Latin1_General_CI_AI =
		substring(replace(program_name, 'SQLAgent - TSQL JobStep (Job ', ''), 1, 34)
		where p.spid = @@SPID

if @thread_name is null
	begin
		set @thread_name = 'AD-HOC'
	end

if @thread_spid is null
	begin
		set @thread_spid = @@SPID
	end


set @message = 'Starting remote data import. Thread ' + @thread_name
exec [dbo].[usp_sqlwatch_internal_log]
		@proc_id = @@PROCID,
		@process_stage = 'A10C61BA-6EE9-40C9-BCD1-DBDCB9A232B7',
		@process_message = @message,
		@process_message_type = 'INFO'

merge [dbo].[sqlwatch_meta_repository_import_thread] as target
using (select thread_name = @thread_name) as source
on target.thread_name = source.thread_name
when matched then 
	delete
when not matched then 
	insert ( thread_name, thread_start_time )
	values (source.thread_name, SYSDATETIME());

while 1=1
	begin
		
		select @sql_instance = null, @object_name = null, @load_type = null, @sql = null, @has_errors = 0

		exec [dbo].[usp_sqlwatch_repository_remote_table_dequeue]
			@sql_instance_out = @sql_instance output,
			@object_name_out = @object_name output,
			@load_type_out = @load_type output

		select 
			@table_name = parsename(@object_name,1),
			@table_schema = parsename(@object_name,2),
			@database = parsename(@object_name,3)

		begin try
			begin transaction 
			exec [dbo].[usp_sqlwatch_repository_remote_table_import_worker] 
				@sql_instance = @sql_instance,
				@object_name = @object_name,
				@load_type = @load_type
			commit transaction 
		end try
			begin catch
				if @@TRANCOUNT > 0
				rollback transaction
				/*	In rare cases we may get Foreign key errors if the header table does not contain all data.
					Th snapshot_header table is the only delta loaded, logger table that has childs.
					Any other parent table is meta and always full loaded to avoid inconsistencies, however
					snapshot_header can be quite big so we load deltas. In case we have gaps,
					we will attempt to force a FULL load to try and fill any gaps	*/
				if ERROR_MESSAGE() like '%The INSERT statement conflicted with the FOREIGN KEY constraint%' 
					and ERROR_MESSAGE() like '%dbo.sqlwatch_logger_snapshot_header%' and @load_type = 'D'
					begin
						set @object_name_t = @database + '.dbo.sqlwatch_logger_snapshot_header'							
						set @message = 'FOREIGN KEY constraint failure, forcing full table load (sqlwatch_logger_snapshot_header)'

						exec [dbo].[usp_sqlwatch_internal_log]
								@proc_id = @@PROCID,
								@process_stage = 'FE99CFB8-7736-438B-8F21-9E04789B79A9',
								@process_message = @message,
								@process_message_type = 'WARNING'
							
						begin try

								/* rerun header table */
								exec [dbo].[usp_sqlwatch_repository_remote_table_import_worker] 
									@sql_instance = @sql_instance,
									@object_name = @object_name_t,
									@load_type = 'F'

								/* now re-run the child table */
								exec [dbo].[usp_sqlwatch_repository_remote_table_import_worker] 
									@sql_instance = @sql_instance,
									@object_name = @object_name,
									@load_type = @load_type

							GoTo Success
						end try
						begin catch
							if @@TRANCOUNT > 0
							rollback transaction
					
							set @has_errors = 1

							update dbo.[sqlwatch_meta_repository_import_status]
								set import_status = 'ERROR', [import_end_time] = SYSDATETIME(), [exec_proc] = @thread_name + ' ' + @thread_spid
							where sql_instance = @sql_instance
							and object_name = @object_name

							exec [dbo].[usp_sqlwatch_internal_log]
									@proc_id = @@PROCID,
									@process_stage = '4473A8F5-060C-4279-9B03-D81E5F0C5AE6',
									@process_message = 'Failed to force FULL table import.  Check errors in the worker thread.',
									@process_message_type = 'ERROR'

							GoTo NextItem
						end catch

						GoTo NextItem

						/*	remove any childs that we are not able to process because the parent has failed */
						delete from [dbo].[sqlwatch_meta_repository_import_queue]
						where sql_instance = @sql_instance
						and parent_object_name = @object_name
					end
				else
					begin
						if @@TRANCOUNT > 0
						rollback transaction

						set @has_errors = 1

						update dbo.[sqlwatch_meta_repository_import_status]
							set import_status = 'ERROR', [import_end_time] = SYSDATETIME(), [exec_proc] = @thread_name + ' ' + @thread_spid
						where sql_instance = @sql_instance
						and object_name = @object_name

						exec [dbo].[usp_sqlwatch_internal_log]
								@proc_id = @@PROCID,
								@process_stage = 'F649C8DB-8703-4AFB-AE65-C7E04E06AAD1',
								@process_message = 'Failed to import table. Check errors in the worker thread.',
								@process_message_type = 'ERROR'
					
						/*	remove any childs that we are not able to process because the parent has failed */
						delete from [dbo].[sqlwatch_meta_repository_import_queue]
						where sql_instance = @sql_instance
						and parent_object_name = @object_name

						GoTo NextItem
					end
			end catch
		
			Success:

			update dbo.[sqlwatch_meta_repository_import_status]
				set import_status = 'Success', [import_end_time] = SYSDATETIME(), [exec_proc] = @thread_name + ' ' + @thread_spid
			where sql_instance = @sql_instance
			and object_name = @object_name

			delete from [dbo].[sqlwatch_meta_repository_import_queue]
			where sql_instance = @sql_instance
			and object_name = @object_name

		NextItem:

		if @object_name is null
			begin
				Goto Finish
			end
	end


Finish:
set @message = 'Finished remote data import. Thread ' + @thread_name + ' ' + @thread_spid
exec [dbo].[usp_sqlwatch_internal_log]
		@proc_id = @@PROCID,
		@process_stage = '486B5F96-C8BA-441C-8D96-D25B0F2A0075',
		@process_message = @message,
		@process_message_type = 'INFO'

delete from [dbo].[sqlwatch_meta_repository_import_thread]
where thread_name = @thread_name

if @has_errors = 1
	begin
		declare @error_message nvarchar(max)
		set @error_message = 'Errors during execution (' + OBJECT_NAME(@@PROCID) + ')'
		--print all errors and terminate the batch which will also fail the agent job for the attention:
		raiserror ('%s',16,1,@error_message)
	end

