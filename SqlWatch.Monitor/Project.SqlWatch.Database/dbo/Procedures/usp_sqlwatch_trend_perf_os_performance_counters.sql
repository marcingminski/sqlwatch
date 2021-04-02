CREATE PROCEDURE [dbo].[usp_sqlwatch_trend_perf_os_performance_counters]
	@interval_minutes smallint = 60,
	@valid_days smallint = 720
as

set xact_abort on;
set nocount on;

declare		@snapshot_time datetime2(0),
			@first_snapshot_time datetime2(0), 
			@last_snapshot_time datetime2(0),
			@snapshot_time_utc_offset int

  select 
	  @first_snapshot_time =min(snapshot_time)
	, @last_snapshot_time=max(snapshot_time)
	, @snapshot_time_utc_offset = max(snapshot_time_utc_offset)
  from [dbo].[sqlwatch_logger_snapshot_header] h
  where datepart(hour,h.snapshot_time) = datepart(hour,dateadd(hour,-1,getutcdate()))
  and datepart(day,h.snapshot_time) = datepart(day,dateadd(hour,-1,getutcdate()))
  and datepart(month,h.snapshot_time) = datepart(month,dateadd(hour,-1,getutcdate()))
  and datepart(year,h.snapshot_time) = datepart(year,dateadd(hour,-1,getutcdate()))

  insert into [dbo].[sqlwatch_trend_perf_os_performance_counters] (
		performance_counter_id
		, instance_name
		, sql_instance
		, cntr_value_calculated_avg
		, cntr_value_calculated_min
		, cntr_value_calculated_max
		, cntr_value_calculated_sum
		, interval_minutes
		, snapshot_time
		, snapshot_time_offset
		, valid_until
		)
  select pc.[performance_counter_id]
      ,pc.[instance_name]
      ,pc.[sql_instance]
      ,[cntr_value_calculated_avg] = avg(pc.[cntr_value_calculated])
	  ,[cntr_value_calculated_min] = min(pc.[cntr_value_calculated])
	  ,[cntr_value_calculated_max] = max(pc.[cntr_value_calculated])
	  ,[cntr_value_calculated_sum] = sum(pc.[cntr_value_calculated])
	  ,[interval_minutes] = @interval_minutes --datediff(minute,@first_snapshot_time,@last_snapshot_time)
	  , snapshot_time = dateadd(minute, datediff(minute, 0, h.snapshot_time ) / @interval_minutes * @interval_minutes, 0)
	  ,[snapshot_time_offset] = TODATETIMEOFFSET ( dateadd(minute, datediff(minute, 0, h.snapshot_time ) / @interval_minutes * @interval_minutes, 0) , h.snapshot_time_utc_offset )  
		/*
	  , snapshot_time = dateadd(hour, datediff(hour, 0, h.snapshot_time), 0)
	  ,[snapshot_time_offset] = TODATETIMEOFFSET ( dateadd(hour, datediff(hour, 0, h.snapshot_time), 0) , h.snapshot_time_utc_offset )  
		*/
	   , valid_until = dateadd(day,@valid_days,getutcdate())
  from [dbo].[sqlwatch_logger_perf_os_performance_counters] pc
  
  inner join [dbo].[sqlwatch_logger_snapshot_header] h
	on pc.sql_instance = h.sql_instance
	and pc.snapshot_time = h.snapshot_time
	and pc.snapshot_type_id = pc.snapshot_type_id

  inner join [dbo].[sqlwatch_meta_performance_counter] mpc
	on mpc.performance_counter_id = pc.performance_counter_id
	and mpc.sql_instance = pc.sql_instance
 
  where mpc.cntr_type <> 1073939712  --exclude base counters
  and h.snapshot_time >= @first_snapshot_time
  and h.snapshot_time <= @last_snapshot_time
  and pc.sql_instance = dbo.ufn_sqlwatch_get_servername()

  group by  pc.[performance_counter_id]
      ,pc.[instance_name]
      ,pc.[sql_instance]  
	  , dateadd(minute, datediff(minute, 0, h.snapshot_time ) / @interval_minutes * @interval_minutes, 0)
	  , TODATETIMEOFFSET ( dateadd(minute, datediff(minute, 0, h.snapshot_time ) / @interval_minutes * @interval_minutes, 0) , h.snapshot_time_utc_offset )  
