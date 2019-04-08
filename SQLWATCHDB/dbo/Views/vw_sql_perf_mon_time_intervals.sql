CREATE VIEW [dbo].[vw_sql_perf_mon_time_intervals] AS
select 
		[spapshot_interval_start]
	,	[snapshot_interval_end] = dateadd(mi, [report_time_interval_minutes], [spapshot_interval_start])
	,	[first_snapshot_time]	= MIN(i.snapshot_time)
	,	[last_snapshot_time]	= MAX(i.snapshot_time)
	,	[snapshot_age_hours]	= datediff(hour,dateadd(mi, [report_time_interval_minutes], [spapshot_interval_start]),GETDATE())
	,	[report_time_interval_minutes]
from [dbo].[sqlwatch_logger_snapshot_header] s
inner join (
	select
			[snapshot_time]
		 ,	[spapshot_interval_start] = convert(datetime,dateadd(mi,(datediff(mi,0, [snapshot_time])/ ti.[report_time_interval_minutes]) * ti.[report_time_interval_minutes],0))
		 ,	ti.[report_time_interval_minutes]
	from [dbo].[sqlwatch_logger_snapshot_header]
	cross apply (
		select top 5 report_time_interval_minutes
		from [dbo].[sql_perf_mon_config_report_time_interval]
		order by report_time_interval_minutes
		) ti
	) i
	on s.snapshot_time > [spapshot_interval_start]
	and s.snapshot_time <= dateadd(mi, [report_time_interval_minutes], [spapshot_interval_start])
group by [spapshot_interval_start], [report_time_interval_minutes]