CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_meta_add_database]
	@xdoc int,
	@sql_instance varchar(32)
as
begin
	set nocount on;

	merge [dbo].[sqlwatch_meta_database] as target
	using (
		select 
			  [database_name] 
			, [database_create_date] 
			, [is_auto_close_on] 
			, [is_auto_shrink_on]
			, [is_auto_update_stats_on] 
			, [user_access] 
			, [state] 
			, [snapshot_isolation_state] 
			, [is_read_committed_snapshot_on]  
			, [recovery_model] 
			, [page_verify_option] 
			, [sql_instance] = @sql_instance
		from openxml (@xdoc, '/MetaDataSnapshot/sys_databases/row',1) 
			with (
				  [database_name] sysname
				, [database_create_date] datetime2(3)
				, [is_auto_close_on] bit
				, [is_auto_shrink_on] bit
				, [is_auto_update_stats_on] bit
				, [user_access] tinyint
				, [state] tinyint
				, [snapshot_isolation_state] tinyint
				, [is_read_committed_snapshot_on]  bit
				, [recovery_model] tinyint
				, [page_verify_option] tinyint
			)	
	)
	as source
		on (
				source.[database_name] = target.[database_name] collate database_default
			and source.[database_create_date] = target.[database_create_date]
			and source.[sql_instance] = target.[sql_instance] collate database_default
		)
	/* dropped databases are going to be updated to current = 0 */
	when not matched by source and target.sql_instance = @sql_instance then
		update set [is_current] = 0

	when matched then
		update set [is_current] = 1,
				[date_last_seen] = getutcdate(),
				[is_auto_close_on] = source.[is_auto_close_on],
				[is_auto_shrink_on] = source.[is_auto_shrink_on],
				[is_auto_update_stats_on] = source.[is_auto_update_stats_on],
				[user_access] = source.[user_access],
				[snapshot_isolation_state] = source.[snapshot_isolation_state],
				[is_read_committed_snapshot_on] = source.[is_read_committed_snapshot_on],
				[recovery_model] = source.[recovery_model],
				[page_verify_option] = source.[page_verify_option]
			
	when not matched by target then
		insert ([database_name], [database_create_date], [sql_instance], [is_auto_close_on], [is_auto_shrink_on], [is_auto_update_stats_on]
			,[user_access], [state], [snapshot_isolation_state], [is_read_committed_snapshot_on], [recovery_model], [page_verify_option]
			,[date_last_seen], [is_current]
		)
		values (source.[database_name], source.[database_create_date], source.[sql_instance]
			, source.[is_auto_close_on], source.[is_auto_shrink_on], source.[is_auto_update_stats_on]
			, source.[user_access], source.[state], source.[snapshot_isolation_state]
			, source.[is_read_committed_snapshot_on], source.[recovery_model]
			, source.[page_verify_option]
			, getutcdate(), 1
			);
end;