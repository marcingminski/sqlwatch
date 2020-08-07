CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_retention]
as

/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	usp_sqlwatch_internal_retention

 Description:
	Process retention of each snapshot based on the snapshot_retention_days.
	Deleting from the header [sqlwatch_logger_snapshot_header] will also delete from child tables through cascade
	action. To avoid blowing transaction logs we have running batches of 500 rows by default. This can be adjusted
	by passing different batch size as a parameter. This procedure should run every hour so there is never too 
	much to delete. Do not leave this to run once a day or once a week, the more often it runs the less it will do.
	Average execution does not exceed few seconds.

 Parameters
	N/A

 Author:
	Marcin Gminski

 Change Log:
	1.0		2019-08		- Marcin Gminski,	Initial version
	1.1		2019-11-29	- Marcin Gminski,	Ability to only leave most recent snapshot with -1 retention
	1.2		2019-12-07	- Marcin Gminski,	Added retention of the action queue
	1.3		2019-12-09	- Marcin Gminski,	build deletion keys out of the loop to improve loop performance and reduce contention
	1.4		2019-12-31	- Marcin Gminski,	changed hardcoded to configurable retention periods for non-logger tables,
											replaced input parameters with global config
	1.5		2020-02-18	- Marcin Gminski,	fixed an issue where retention would not be correctly applied due to null variables,
											code cleanse
	1.6		2020-05-13  - Marcin Gminski,	batch up app_log retention
-------------------------------------------------------------------------------------------------------------------
*/
set nocount on;
set xact_abort on;

declare @snapshot_type_id tinyint,
		@batch_size smallint,
		@row_count int,
		@action_queue_retention_days_failed smallint,
		@action_queue_retention_days_success smallint,
		@application_log_retention_days smallint

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
	where sql_instance = @@SERVERNAME
	and [report_time] < (
		select dateadd(day,-[snapshot_retention_days_trend],getutcdate())
		from [dbo].[sqlwatch_config_snapshot_type]
		where snapshot_type_id = @snapshot_type_id
		and [snapshot_retention_days_trend] is not null
		)
	Print 'Deleted ' + convert(varchar(max),@@ROWCOUNT) + ' records from [dbo].[sqlwatch_trend_perf_os_performance_counters]'

go