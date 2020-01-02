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
			, BC = binary_checksum([is_auto_close_on], [is_auto_shrink_on], [is_auto_update_stats_on]
								 , [user_access], [state], [snapshot_isolation_state] , [is_read_committed_snapshot_on] 
							 	 , [recovery_model] , [page_verify_option])
		from dbo.vw_sqlwatch_sys_databases
		--union all
		/* mssqlsystemresource database appears in the performance counters
		so we need it as a dimensions to be able to filter in the report */
		--select 'mssqlsystemresource', '1970-01-01', @@SERVERNAME
		--	, null, null, null, null, null, null, null, null, null, null
	) as source
		on (
				source.[name] = target.[database_name] collate database_default
			and source.[create_date] = target.[database_create_date]
			and source.[sql_instance] = target.[sql_instance] collate database_default
		)
	/* dropped databases are going to be updated to current = 0 */
	when not matched by source and target.sql_instance = @@SERVERNAME then
		update set [is_record_deleted] = 1

	when matched then
		update set [date_last_seen] = GETUTCDATE()
			,[is_record_deleted] = 0
			,[is_auto_close_on] = case when target.[is_auto_close_on] is null or target.[is_auto_close_on] <> source.[is_auto_close_on] then source.[is_auto_close_on] else target.[is_auto_close_on] end
			,[is_auto_shrink_on] = case when target.[is_auto_shrink_on] is null or target.[is_auto_shrink_on] <> source.[is_auto_shrink_on] then source.[is_auto_shrink_on] else target.[is_auto_shrink_on] end
			,[is_auto_update_stats_on] = case when target.[is_auto_update_stats_on] is null or target.[is_auto_update_stats_on] <> source.[is_auto_update_stats_on] then source.[is_auto_update_stats_on] else target.[is_auto_update_stats_on] end
			,[user_access] = case when target.[user_access] is null or target.[user_access] <> source.[user_access] then source.[user_access] else target.[user_access] end
			,[state] = case when target.[state] is null or target.[state] <> source.[state] then source.[state] else target.[state] end
			,[snapshot_isolation_state] = case when target.[snapshot_isolation_state] is null or target.[snapshot_isolation_state] <> source.[snapshot_isolation_state] then source.[snapshot_isolation_state] else target.[snapshot_isolation_state] end
			,[is_read_committed_snapshot_on] = case when target.[is_read_committed_snapshot_on] is null or target.[is_read_committed_snapshot_on] <> source.[is_read_committed_snapshot_on] then source.[is_read_committed_snapshot_on] else target.[is_read_committed_snapshot_on] end
			,[recovery_model] = case when target.[recovery_model] is null or target.[recovery_model] <> source.[recovery_model] then source.[recovery_model] else target.[recovery_model] end
			,[page_verify_option] = case when target.[page_verify_option] is null or target.[page_verify_option] <> source.[page_verify_option] then source.[page_verify_option] else target.[page_verify_option] end

			,[date_updated] = case when binary_checksum(target.[is_auto_close_on], target.[is_auto_shrink_on], target.[is_auto_update_stats_on]
								 , target.[user_access], target.[state], target.[snapshot_isolation_state] , target.[is_read_committed_snapshot_on] 
							 	 , target.[recovery_model] , target.[page_verify_option]) <> source.BC then getutcdate() else target.[date_updated] end
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