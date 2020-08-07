CREATE PROCEDURE [dbo].[usp_sqlwatch_trend_perf_os_performance_counters]
as

set xact_abort on;
set nocount on;

declare @snapshot_time datetime2(0)

/* TODO - Retention */


----15 minutes
--select @snapshot_time = max(snapshot_time)
--from [dbo].[sqlwatch_trend_perf_os_performance_counters]
--where [trend_interval_minutes] = 15
--and sql_instance = @@SERVERNAME

--insert into [dbo].[sqlwatch_trend_perf_os_performance_counters]
--select pc.[performance_counter_id]
--      ,pc.[instance_name]
--      ,[snapshot_time] = t.[interval_minutes_15]
--      ,pc.[sql_instance]
--      ,[cntr_value_calculated] = avg(pc.[cntr_value_calculated])
--	  ,[aggregation_interval_minutes] = 15
--  from [dbo].[sqlwatch_logger_perf_os_performance_counters] pc
  
--  inner join [dbo].[sqlwatch_logger_snapshot_header] h
--	on pc.sql_instance = h.sql_instance
--	and pc.snapshot_time = h.snapshot_time
--	and pc.snapshot_type_id = pc.snapshot_type_id
  
--  inner join [dbo].[vw_sqlwatch_report_dim_time] t
--	on t.[report_time] = h.[report_time]

--  inner join [dbo].[sqlwatch_meta_performance_counter] mpc
--	on mpc.performance_counter_id = pc.performance_counter_id
--	and mpc.sql_instance = pc.sql_instance

-- -- left join [dbo].[sqlwatch_aggregate_perf_os_performance_counters] apc
--	--on apc.sql_instance = pc.sql_instance
--	--and apc.performance_counter_id = pc.performance_counter_id
--	--and apc.snapshot_time = t.[interval_minutes_15]
--	--and apc.[aggregation_interval_minutes] = 15
 
-- --exclude base counters
--  where mpc.cntr_type <> 1073939712
--  and t.[interval_minutes_15] < dateadd(minute,-15,getutcdate())
--  and t.[interval_minutes_15] > isnull(@snapshot_time,'1970-01-01')
--  --and apc.snapshot_time is null

--  group by  pc.[performance_counter_id]
--      ,pc.[instance_name]
--      ,pc.[sql_instance]
--	  ,t.[interval_minutes_15]
--  option (recompile);


--60 minutes
select @snapshot_time = max([report_time])
from [dbo].[sqlwatch_trend_perf_os_performance_counters]
where [trend_interval_minutes] = 60
and sql_instance = @@SERVERNAME

insert into [dbo].[sqlwatch_trend_perf_os_performance_counters] (
	performance_counter_id
	, instance_name
	, report_time
	, sql_instance
	, cntr_value_calculated_avg
	, cntr_value_calculated_min
	, cntr_value_calculated_max
	, trend_interval_minutes
	, snapshot_time_offset
	)
select pc.[performance_counter_id]
      ,pc.[instance_name]
      ,[snapshot_time] = t.[interval_minutes_60]  
      ,pc.[sql_instance]
      ,[cntr_value_calculated_avg] = avg(pc.[cntr_value_calculated])
	  ,[cntr_value_calculated_min] = min(pc.[cntr_value_calculated])
	  ,[cntr_value_calculated_max] = max(pc.[cntr_value_calculated])
	  ,[aggregation_interval_minutes] = 60
	  ,[snapshot_time_offset] = TODATETIMEOFFSET ( t.[interval_minutes_60] , h.snapshot_time_utc_offset )  
  from [dbo].[sqlwatch_logger_perf_os_performance_counters] pc
  
  inner join [dbo].[sqlwatch_logger_snapshot_header] h
	on pc.sql_instance = h.sql_instance
	and pc.snapshot_time = h.snapshot_time
	and pc.snapshot_type_id = pc.snapshot_type_id
  
  inner join [dbo].[vw_sqlwatch_report_dim_time] t
	on t.[report_time] = h.[report_time]

  inner join [dbo].[sqlwatch_meta_performance_counter] mpc
	on mpc.performance_counter_id = pc.performance_counter_id
	and mpc.sql_instance = pc.sql_instance

 -- left join [dbo].[sqlwatch_aggregate_perf_os_performance_counters] apc
	--on apc.sql_instance = pc.sql_instance
	--and apc.performance_counter_id = pc.performance_counter_id
	--and apc.snapshot_time = t.[interval_minutes_60]
	--and apc.[aggregation_interval_minutes] = 60
 
 --exclude base counters
  where mpc.cntr_type <> 1073939712
  and t.[interval_minutes_60] < dateadd(minute,-60,getutcdate())
  and t.[interval_minutes_60] > isnull(@snapshot_time,'1970-01-01')
  --and apc.snapshot_time is null

  and pc.sql_instance = @@SERVERNAME

  group by  pc.[performance_counter_id]
      ,pc.[instance_name]
      ,pc.[sql_instance]
	  ,t.[interval_minutes_60]
	  ,TODATETIMEOFFSET ( t.[interval_minutes_60] , h.snapshot_time_utc_offset )  
  option (recompile);