CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_retention]
as
begin

	set nocount on;

	declare @snapshot_type_id tinyint,
			@batch_size smallint,
			@row_count int,
			@action_queue_retention_days_failed smallint,
			@action_queue_retention_days_success smallint,
			@application_log_retention_days smallint,
			@sql_instance varchar(32) = dbo.ufn_sqlwatch_get_servername(),
			@event_time datetime2(3)
			;

	select @batch_size = [dbo].[ufn_sqlwatch_get_config_value](6, null),
			@action_queue_retention_days_failed = [dbo].[ufn_sqlwatch_get_config_value](3, null),
			@action_queue_retention_days_success = [dbo].[ufn_sqlwatch_get_config_value](4, null),
			@application_log_retention_days = [dbo].[ufn_sqlwatch_get_config_value](1, null),
			@row_count = 1 -- initalitzaion, otherwise loop will not be entered
			;

	declare @cutoff_dates as table (
		snapshot_time datetime2(0),
		sql_instance varchar(32),
		snapshot_type_id tinyint,
		primary key ([sql_instance], [snapshot_type_id])
	)
	
	/*	To account for central repository, we need a list of all possible snapshot types cross joined with servers list
		and calculate retention times from the type. This cannot be done for retention -1 as for that scenario, 
		we need to know the latest current snapshot.	*/
	insert into @cutoff_dates
		select snapshot_time = case when st.snapshot_retention_days >0 then dateadd(day,-st.snapshot_retention_days,GETUTCDATE()) else null end
			, si.sql_instance
			, st.snapshot_type_id
		from [dbo].[sqlwatch_config_snapshot_type] st
		cross join [dbo].[sqlwatch_config_sql_instance] si

	/*	Once we have a list of snapshots and dates, 
		we can get max snapshot for the rest - to avoid excesive scanning
		and try force a seek, we are limiting this to only those have not got date yet i.e. snapshot types = -1	*/
	update c
		set snapshot_time = t.snapshot_time
	from @cutoff_dates c
	inner join (
		select snapshot_time=max(sh.snapshot_time), sh.sql_instance, sh.snapshot_type_id
		from dbo.sqlwatch_logger_snapshot_header sh
		inner join @cutoff_dates cd
			on cd.sql_instance = sh.sql_instance collate database_default
			and cd.snapshot_type_id = sh.snapshot_type_id
		where cd.snapshot_time is null
		group by sh.sql_instance, sh.snapshot_type_id
		) t
	on t.sql_instance = c.sql_instance collate database_default
	and t.snapshot_type_id = c.snapshot_type_id

	while @row_count > 0
		begin
			begin tran
				delete top (@batch_size) h
				from dbo.[sqlwatch_logger_snapshot_header] h (readpast)
				inner join @cutoff_dates c 
					on h.snapshot_time < c.snapshot_time
					and h.sql_instance = c.sql_instance
					and h.snapshot_type_id = c.snapshot_type_id

				-- do not remove baseline snapshots:
				where h.snapshot_time not in (
					select snapshot_time
					from [dbo].[sqlwatch_meta_snapshot_header_baseline]
					where sql_instance = h.sql_instance
					)

				set @row_count = @@ROWCOUNT;
				print 'Deleted ' + convert(varchar(max),@row_count) + ' records from [dbo].[sqlwatch_logger_snapshot_header]'
			commit tran
		end

	/* Application log retention */
	set @row_count = 1
	set @event_time = dateadd(day,-@application_log_retention_days, SYSDATETIME());

	while @row_count > 0
		begin
			delete top (@batch_size)
			from dbo.sqlwatch_app_log
			where event_time < @event_time;

			set @row_count = @@ROWCOUNT
			Print 'Deleted ' + convert(varchar(max),@@ROWCOUNT) + ' records from [dbo].[sqlwatch_app_log]'
		end

		/*	Trend tables retention.
			These are detached from the header so we can keep more history and in a slightly different format to utilise less storage.
			We are going to have remove data from these tables manually	*/

		--set @snapshot_type_id = 1 --Performance Counters
		--delete from [dbo].[sqlwatch_trend_logger_dm_os_performance_counters]
		--where [original_sql_instance] = @sql_instance
		--and getutcdate() > valid_until
		--Print 'Deleted ' + convert(varchar(max),@@ROWCOUNT) + ' records from [dbo].[sqlwatch_trend_perf_os_performance_counters]'

		----- purge removed items
		declare @sql varchar(max),
				@purge_after_days tinyint,
				@row_batch_size int;

		select 
			@purge_after_days = [dbo].[ufn_sqlwatch_get_config_value]  (2, null),
			@row_batch_size = [dbo].[ufn_sqlwatch_get_config_value]  (5, null),
			@sql = 'declare @rows_affected bigint;';

		select @sql+= '
		set @rows_affected = 1;
		while @rows_affected > 0
			begin
				delete top (' + case 
					when TABLE_NAME like '%meta_database' then '1'
					else convert(varchar(10),@row_batch_size) 
					end + ') 
				from ' + TABLE_SCHEMA + '.' + TABLE_NAME + '
				where ' + COLUMN_NAME + ' < dateadd(day,-' + convert(varchar(10),@purge_after_days) +',getutcdate())
				and ' + COLUMN_NAME + ' is not null;
				set @rows_affected = @@ROWCOUNT;
			end;

			Print ''Purged '' + convert(varchar(10),@rows_affected) + '' rows from ' + TABLE_SCHEMA + '.' + TABLE_NAME + ' '';
		'
		 from INFORMATION_SCHEMA.COLUMNS
		/*	I should have been more careful when naming columns, I ended up having all these variations.
			The exception is base_object_date_last_seen which is different to date_last_seen as it referes to a parent object rather than row in the actual table */
		WHERE (
			COLUMN_NAME in ('deleted_when', 'date_deleted', 'last_seen','last_seen_date','date_last_seen')
			AND TABLE_NAME LIKE 'sqlwatch_meta%'
			)
		OR
			(
			COLUMN_NAME in ('base_object_date_last_seen')
			AND TABLE_NAME = 'sqlwatch_config_check'
			)
		order by case 
			when TABLE_NAME like '%database%' then 1
			when TABLE_NAME like '%master_file%' then 2
			when TABLE_NAME like '%table%' then 3
			when TABLE_NAME like '%index%' then 4
			when TABLE_NAME like '%procedure%' then 5
			else 6 end;

		set nocount on;

		exec (@sql);

		--purge orphaned snapshots. There should not be any becuase of referential integrity but in case keys have become untrusted:
		set @sql = 'declare @rows_affected bigint;';

		select @sql+='
		set @rows_affected = 1;
		while @rows_affected > 0
			begin
				delete top (' + convert(varchar(10),@row_batch_size) + ') l 
				from ' + TABLE_SCHEMA + '.' + TABLE_NAME + ' l
				left join [dbo].[sqlwatch_logger_snapshot_header] h
				on h.sql_instance = l.sql_instance
				and h.snapshot_type_id = l.snapshot_type_id
				and h.snapshot_time = l.snapshot_time
				where h.snapshot_time is null;
				set @rows_affected = @@ROWCOUNT;
			end;'
		from INFORMATION_SCHEMA.TABLES
		where TABLE_NAME like '%logger%'
		and TABLE_NAME not like '%config%'
		and TABLE_TYPE = 'BASE TABLE';

		exec (@sql);

end;