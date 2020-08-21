CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_database]
as
	set nocount on;

	/*	using database_create_data to distinguish databases that have been dropped and re-created 
		this is particulary useful when doing performance testing and we are re-creating test databases throughout the process and want to compare them later.
		However, with every SQL Server restart, tempdb will be recreated and will have new date_created. On some dev and uat servers we may end up with dozen or more
		tempdbs. To account for this, we are going to default the create_date for tempdb to '1970-01-01'
	*/
	;merge [dbo].[sqlwatch_meta_database] as target
	using (
		select [name], [create_date] = case when [name] = 'tempdb' then convert(datetime,'1970-01-01') else [create_date] end, [sql_instance]
			, [is_auto_close_on], [is_auto_shrink_on], [is_auto_update_stats_on]
			, [user_access], [state], [snapshot_isolation_state] , [is_read_committed_snapshot_on] 
			, [recovery_model] , [page_verify_option] 
			--, BC = binary_checksum([is_auto_close_on], [is_auto_shrink_on], [is_auto_update_stats_on]
			--					 , [user_access], [state], [snapshot_isolation_state] , [is_read_committed_snapshot_on] 
			--				 	 , [recovery_model] , [page_verify_option])
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
		update set [is_current] = 0

	when matched then
		update set [is_current] = 1,
				[date_last_seen] = case when datediff(hour,[date_last_seen],getutcdate()) >= 24 then getutcdate() else [date_last_seen] end,
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
		values (source.[name], source.[create_date], source.[sql_instance]
			, source.[is_auto_close_on], source.[is_auto_shrink_on], source.[is_auto_update_stats_on]
			, source.[user_access], source.[state], source.[snapshot_isolation_state]
			, source.[is_read_committed_snapshot_on], source.[recovery_model]
			, source.[page_verify_option]
			, getutcdate(), 1
			);