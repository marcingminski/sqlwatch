CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_retention]
as

set nocount on;
set xact_abort on;

declare @snapshot_type_id tinyint,
		@batch_size smallint,
		@row_count int,
		@action_queue_retention_days_failed smallint,
		@action_queue_retention_days_success smallint,
		@application_log_retention_days smallint,
		@sql_instance varchar(32) = dbo.ufn_sqlwatch_get_servername();

select @batch_size = [dbo].[ufn_sqlwatch_get_config_value](6, null)
select @action_queue_retention_days_failed = [dbo].[ufn_sqlwatch_get_config_value](3, null)
select @action_queue_retention_days_success = [dbo].[ufn_sqlwatch_get_config_value](4, null)
select @application_log_retention_days = [dbo].[ufn_sqlwatch_get_config_value](1, null)
select @row_count = 1 -- initalitzaion, otherwise loop will not be entered

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
				)

			set @row_count = @@ROWCOUNT
			print 'Deleted ' + convert(varchar(max),@row_count) + ' records from [dbo].[sqlwatch_logger_snapshot_header]'
		commit tran
	end

	/*	delete old records from the action queue */
	delete 
	from [dbo].[sqlwatch_meta_action_queue] 
	where [time_queued] < case when exec_status <> 'FAILED' then dateadd(day,-@action_queue_retention_days_success,sysdatetime()) else dateadd(day,-@action_queue_retention_days_failed,sysdatetime()) end
	Print 'Deleted ' + convert(varchar(max),@@ROWCOUNT) + ' records from [dbo].[sqlwatch_meta_action_queue]'

	/* Application log retention */
set @row_count = 1
while @row_count > 0
	begin
		delete top (@batch_size)
		from dbo.sqlwatch_app_log
		where event_time < dateadd(day,-@application_log_retention_days, SYSDATETIME())

		set @row_count = @@ROWCOUNT
		Print 'Deleted ' + convert(varchar(max),@@ROWCOUNT) + ' records from [dbo].[sqlwatch_app_log]'
	end

	/*	Trend tables retention.
		These are detached from the header so we can keep more history and in a slightly different format to utilise less storage.
		We are going to have remove data from these tables manually	*/

	set @snapshot_type_id = 1 --Performance Counters
	delete from [dbo].[sqlwatch_trend_perf_os_performance_counters]
	where sql_instance = @sql_instance
	and getutcdate() > valid_until
	Print 'Deleted ' + convert(varchar(max),@@ROWCOUNT) + ' records from [dbo].[sqlwatch_trend_perf_os_performance_counters]'

go