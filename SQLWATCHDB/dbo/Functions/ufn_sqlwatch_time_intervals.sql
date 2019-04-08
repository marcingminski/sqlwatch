CREATE FUNCTION [dbo].[ufn_sqlwatch_time_intervals]
(
	@snapshot_type_id tinyint = 1,
	@interval_minutes smallint = null,
	@report_window int = 4,
	@report_end_time datetime = null
)
RETURNS TABLE
AS RETURN (
	/* if no @interval_minutes parameter specified we are going to 
		pick best interval based on report window here */
	with cte_interval_window as (
		select interval_minutes = case when @interval_minutes is null then
			case
				when @report_window <= 1 then 2
				when @report_window <= 4 then 5
				when @report_window <= 24 then 15
				when @report_window <= 168 then 60
				when @report_window <= 720 then 360
			else 1440 end
		else @interval_minutes end
	)
		select
				[first_snapshot_time]	= min([snapshot_time])
			 ,  [last_snapshot_time]	= max([snapshot_time])
			 ,	[spapshot_interval_start]	= convert(datetime,dateadd(mi,(datediff(mi,0, [snapshot_time])/ interval_minutes) * interval_minutes,0))
			 ,	[snapshot_interval_end]		= dateadd(mi, interval_minutes, convert(datetime,dateadd(mi,(datediff(mi,0, [snapshot_time])/ interval_minutes) * interval_minutes,0)))
			 ,	[report_time_interval_minutes] = interval_minutes
			 ,	[snapshot_type_id]
			 ,	[snapshot_age_hours]	= datediff(hour,dateadd(mi, interval_minutes, convert(datetime,dateadd(mi,(datediff(mi,0, [snapshot_time])/ interval_minutes) * interval_minutes,0))),getdate())
		from [dbo].[sqlwatch_logger_snapshot_header]
		cross apply cte_interval_window
		where snapshot_type_id = isnull(@snapshot_type_id,snapshot_type_id)
		and snapshot_time >= DATEADD(HOUR, -@report_window, isnull(@report_end_time,getdate()))
		and snapshot_time <= isnull(@report_end_time,getdate())
		group by 
				convert(datetime,dateadd(mi,(datediff(mi,0, [snapshot_time])/ interval_minutes) * interval_minutes,0))
			,	dateadd(mi, interval_minutes, convert(datetime,dateadd(mi,(datediff(mi,0, [snapshot_time])/ interval_minutes) * interval_minutes,0)))
			,	interval_minutes
			,	[snapshot_type_id]
)
