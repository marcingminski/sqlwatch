CREATE FUNCTION [dbo].[ufn_sqlwatch_time_intervals]
(
	@snapshot_type_id tinyint = null,
	@interval_minutes smallint = null,
	@report_window int = 4,
	@report_end_time datetime = null
	/* for the function to assign default value to an input parametr, the input must be set to DEFAULT, not NULL i.e.
	   select * from [dbo].[ufn_sqlwatch_time_intervals](DEFAULT,DEFAULT,DEFAULT,DEFAULT)
	   instead of
	   select * from [dbo].[ufn_sqlwatch_time_intervals](NULL,NULL,NULL,NULL)
	   to add some flexibility when calling it from stored procedures, I am going to handle null values explicitly */
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
				when @report_window is null then 5 -- default value for report window is 4 hours which would have given 5 minute interval
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
			 ,	[snapshot_age_hours]	= datediff(hour,dateadd(mi, interval_minutes, convert(datetime,dateadd(mi,(datediff(mi,0, [snapshot_time])/ interval_minutes) * interval_minutes,0))),getutcdate())
			 ,  [sql_instance]
			 ,  [snapshot_collection_sequence]  = row_number() over (partition by [sql_instance], [snapshot_type_id] order by min([snapshot_time]))
		from [dbo].[sqlwatch_logger_snapshot_header]
		cross apply cte_interval_window
		where snapshot_type_id = isnull(@snapshot_type_id,snapshot_type_id)
		--set default report window to 4
		and snapshot_time >= DATEADD(HOUR, -isnull(@report_window,4), isnull(@report_end_time,getutcdate()))
		and snapshot_time <= isnull(@report_end_time,getutcdate())
		group by 
				convert(datetime,dateadd(mi,(datediff(mi,0, [snapshot_time])/ interval_minutes) * interval_minutes,0))
			,	dateadd(mi, interval_minutes, convert(datetime,dateadd(mi,(datediff(mi,0, [snapshot_time])/ interval_minutes) * interval_minutes,0)))
			,	interval_minutes
			,	[snapshot_type_id]
			,   [sql_instance]
)
