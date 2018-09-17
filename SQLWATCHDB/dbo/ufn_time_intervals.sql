CREATE FUNCTION [dbo].[ufn_time_intervals]
(
	@snapshot_type_id tinyint = null,
	@interval_minutes smallint = 15,
	@report_window int = 4,
	@report_end_time datetime = '2099-12-31'
)
RETURNS TABLE
AS RETURN (
	select 
			[spapshot_interval_start]
		,	[snapshot_interval_end] = dateadd(mi, @interval_minutes, [spapshot_interval_start])
		,	[first_snapshot_time]	= MIN(i.snapshot_time)
		,	[last_snapshot_time]	= MAX(i.snapshot_time)
		,	[snapshot_age_hours]	= datediff(hour,dateadd(mi, @interval_minutes, [spapshot_interval_start]),GETDATE())
		,	[report_time_interval_minutes] = @interval_minutes
		,	s.[snapshot_type_id]
	from [dbo].[sql_perf_mon_snapshot_header] s
	inner join (
		select
				[snapshot_time]
			 ,	[spapshot_interval_start] = convert(datetime,dateadd(mi,(datediff(mi,0, [snapshot_time])/ @interval_minutes) * @interval_minutes,0))
			 ,	[report_time_interval_minutes] = @interval_minutes
			 ,	[snapshot_type_id]
		from [dbo].[sql_perf_mon_snapshot_header]
		where snapshot_type_id = isnull(@snapshot_type_id,snapshot_type_id)
		and snapshot_time >= DATEADD(HOUR, -@report_window, @report_end_time)
		and snapshot_time <= @report_end_time
		) i
		on s.snapshot_time > [spapshot_interval_start]
		and s.snapshot_time <= dateadd(mi, @interval_minutes, [spapshot_interval_start])
		and i.[snapshot_type_id] = s.[snapshot_type_id]
	where s.snapshot_type_id = isnull(@snapshot_type_id,s.snapshot_type_id)
	and dateadd(mi, @interval_minutes, i.[spapshot_interval_start]) > DATEADD(HOUR, -@report_window, @report_end_time)
	and dateadd(mi, @interval_minutes, i.[spapshot_interval_start]) <= @report_end_time
	group by [spapshot_interval_start], s.snapshot_type_id
	)
GO
