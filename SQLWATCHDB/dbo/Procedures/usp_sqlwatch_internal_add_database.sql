CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_database]
as
	set nocount on;

	/*	using database_create_data to distinguish databases that have been dropped and re-created 
		this is particulary useful when doing performance testing and we are re-creating test databases throughout the process and want to compare them later.
	*/
	;merge [dbo].[sqlwatch_meta_database] as target
	using (
		select [name], [create_date], [sql_instance]
			, [is_auto_close_on], [is_auto_shrink_on], [is_auto_update_stats_on]
			, [user_access], [state], [snapshot_isolation_state] , [is_read_committed_snapshot_on] 
			, [recovery_model] , [page_verify_option] 
		from dbo.vw_sqlwatch_sys_databases
		union all
		/* mssqlsystemresource database appears in the performance counters
		so we need it as a dimensions to be able to filter in the report */
		select 'mssqlsystemresource', '1970-01-01', @@SERVERNAME
			, null, null, null, null, null, null, null, null, null
	) as source
		on (
				source.[name] = target.[database_name] collate database_default
			and source.[create_date] = target.[database_create_date]
			and source.[sql_instance] = target.[sql_instance] collate database_default
		)
	/* dropped databases are going to be updated to current = 0 */
	when matched then
		update set [date_last_seen] = GETUTCDATE()
			,[is_auto_close_on] = source.[is_auto_close_on]
			,[is_auto_shrink_on] = source.[is_auto_shrink_on]
			,[is_auto_update_stats_on] = source.[is_auto_update_stats_on]
			,[user_access] = source.[user_access]
			,[state] = source.[state]
			,[snapshot_isolation_state] = source.[snapshot_isolation_state] 
			,[is_read_committed_snapshot_on] = source.[is_read_committed_snapshot_on]
			,[recovery_model] = source.[recovery_model]
			,[page_verify_option] = source.[page_verify_option]
	/* new databases are going to be inserted */
	when not matched by target then
		insert ([database_name], [database_create_date], [sql_instance], [is_auto_close_on], [is_auto_shrink_on], [is_auto_update_stats_on]
			,[user_access], [state], [snapshot_isolation_state], [is_read_committed_snapshot_on], [recovery_model], [page_verify_option]
		)
		values (source.[name], source.[create_date], source.[sql_instance]
			, source.[is_auto_close_on], source.[is_auto_shrink_on], source.[is_auto_update_stats_on]
			, source.[user_access], source.[state], source.[snapshot_isolation_state]
			, source.[is_read_committed_snapshot_on], source.[recovery_model]
			, source.[page_verify_option]
			);

	/*	the above only accounts for databases that have been removed and re-added
		if you rename database it will be treated as if it was removed and new
		database created so you will lose history continuation. Why would you
		rename a database anyway */