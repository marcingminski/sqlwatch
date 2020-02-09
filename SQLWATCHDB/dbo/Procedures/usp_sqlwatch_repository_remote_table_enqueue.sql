CREATE PROCEDURE [dbo].[usp_sqlwatch_repository_remote_table_enqueue]
	@force_full_load bit = 0
as

declare @batch_id uniqueidentifier = NEWID()

delete from [dbo].[sqlwatch_meta_repository_import_queue]
where not exists (select * from [dbo].[sqlwatch_meta_repository_import_thread])

if not exists (select * from [dbo].[sqlwatch_meta_repository_import_queue])
	begin
		;with cte_queue as (
			select sql_instance, 
				[object_name] = sqlwatch_database_name + '.' + t.TABLE_SCHEMA + '.' + t.TABLE_NAME ,
				[time_queued] = SYSUTCDATETIME(),
				[import_batch_id] = @batch_id,

				/* dependency object */
				[parent_object_name] = sqlwatch_database_name + '.' + t.TABLE_SCHEMA + '.' + case t.TABLE_NAME
					when 'sqlwatch_meta_server' then null
					when 'sqlwatch_meta_database' then 'sqlwatch_meta_server'
					when 'sqlwatch_meta_table' then 'sqlwatch_meta_database'
					when 'sqlwatch_meta_agent_job_step' then 'sqlwatch_meta_server'
					when 'sqlwatch_meta_master_file' then 'sqlwatch_meta_database'
					when 'sqlwatch_meta_index_missing' then 'sqlwatch_meta_table'
					when 'sqlwatch_meta_index' then 'sqlwatch_meta_table'
					else 
						case 
							when t.TABLE_NAME like 'sqlwatch_meta%' then 'sqlwatch_meta_server'
							when t.TABLE_NAME = 'sqlwatch_logger_snapshot_header' then 'sqlwatch_meta_server'
							when t.TABLE_NAME like 'sqlwatch_logger%' then 'sqlwatch_logger_snapshot_header'
						else null end
					end ,

					[priority] = case when t.TABLE_NAME like 'sqlwatch_meta%' then 1 else 2 end
			from [dbo].[sqlwatch_config_sql_instance] s
				inner join INFORMATION_SCHEMA.TABLES t
				on TABLE_TYPE = 'BASE TABLE'
				and (
						TABLE_NAME LIKE 'sqlwatch_meta%'
					or	TABLE_NAME LIKE 'sqlwatch_logger%'
					)
				and TABLE_NAME NOT IN (
				/* do not pull any columns that have no meaning outside of the local instance
					maybe the logger_log would be useful to pull into central repo but will leave it out for now	*/
					  'sqlwatch_meta_action_queue','sqlwatch_logger_log'
					, 'sqlwatch_logger_check_action'
					, 'sqlwatch_app_log'
				)

				/* exclude central repo tables as they will be empty on the remotes anyway */
				and TABLE_NAME NOT LIKE ('sqlwatch_meta_repository_%')

				/* tables not yet used */
				and TABLE_NAME NOT IN (
					'sqlwatch_meta_sql_text'
				)

				/* linked servers do not support xml columns, lets skip these for now	*/
				and TABLE_NAME NOT IN (
					'THIS IS NOW SUPPORTED AND SHOULD WORK'
					--'sqlwatch_logger_xes_blockers', 'sqlwatch_logger_whoisactive '
					--select TABLE_NAME from INFORMATION_SCHEMA.COLUMNS
					--where DATA_TYPE = 'xml'
				)
			where [repo_collector_is_active] = 1
			and sql_instance <> @@SERVERNAME
			)

			insert into [dbo].[sqlwatch_meta_repository_import_queue] ([sql_instance], [object_name], [time_queued], [import_batch_id], [parent_object_name], [priority], [load_type])
			select s.[sql_instance], s.[object_name], s.[time_queued], s.[import_batch_id], s.[parent_object_name], s.[priority]
				,[load_type] = case 
					
					--when object_name like '%sqlwatch_logger_snapshot_header' then 'F' 
					when object_name like '%sqlwatch_logger%' and @force_full_load = 0 then 'D' 
					
					else 'F' end
					
			from cte_queue s
	end
else
	begin
		declare @message nvarchar(max) = 'Queue is not empty. In order to preserve data integrity, existing queue must complete first.'
		exec [dbo].[usp_sqlwatch_internal_log]
				@proc_id = @@PROCID,
				@process_stage = '19079A5C-F4C2-4268-9631-D47F419106E7',
				@process_message = @message,
				@process_message_type = 'WARNING'
	end


	merge [dbo].[sqlwatch_meta_repository_import_status] as target
	using [dbo].[sqlwatch_meta_repository_import_queue] as source
	on target.sql_instance = source.sql_instance
	and target.object_name = source.object_name

	when not matched then
		insert ([sql_instance], [object_name])
		values (source.[sql_instance], source.[object_name]);