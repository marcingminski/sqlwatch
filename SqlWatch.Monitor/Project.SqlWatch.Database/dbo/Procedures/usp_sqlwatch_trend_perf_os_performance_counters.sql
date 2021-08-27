CREATE PROCEDURE [dbo].[usp_sqlwatch_trend_perf_os_performance_counters]
	@timer_id uniqueidentifier
as
begin
	set nocount on;

	declare @interval_seconds int, 
			@start datetime2(0),
			@snapshot_type_id tinyint,
			@snapshot_time_new datetime2(0),
			@sql_instance varchar(32) = @@SERVERNAME
			;

	select @interval_seconds = timer_seconds
	from dbo.sqlwatch_config_timer
	where timer_id = @timer_id;

	set @start = dateadd(SECOND,-@interval_seconds,getutcdate());

	select @snapshot_type_id = snapshot_type_id
	from dbo.sqlwatch_config_snapshot_type
	where timer_id = @timer_id;

	--we would have to create new snapshot header for each instance in the repository
	--the alternative to have one header would be to change the code:
	--select original_instance_name = pc.sql_instance, sql_instance = @@SERVERNAME
	--whilst this may be a little confusing it is a better approach than looping through each instance

    exec [dbo].[usp_sqlwatch_internal_logger_new_header] 
	        @snapshot_time_new = @snapshot_time_new OUTPUT,
	        @snapshot_type_id = @snapshot_type_id,
            @sql_instance = @sql_instance
			;

	insert into [dbo].[sqlwatch_trend_logger_dm_os_performance_counters]
	(
		[performance_counter_id], 
		[instance_name],
		[original_sql_instance],
		[cntr_value_calculated_avg],
		[cntr_value_calculated_min],
		[cntr_value_calculated_max],
		[cntr_value_calculated_sum],
		[original_snapshot_time_from],
		[original_snapshot_time_to],
		sample_count,
		[snapshot_time],
		snapshot_type_id,
		sql_instance
	)
	
	select 
		pc.[performance_counter_id]
		, pc.[instance_name]
		, original_sql_instance = pc.[sql_instance]
		, [cntr_value_calculated_avg] = avg(pc.[cntr_value_calculated])
		, [cntr_value_calculated_min] = min(pc.[cntr_value_calculated])
		, [cntr_value_calculated_max] = max(pc.[cntr_value_calculated])
		, [cntr_value_calculated_sum] = sum(pc.[cntr_value_calculated])
		, original_snapshot_time_from = min(snapshot_time)
		, original_snapshot_time_to = max(snapshot_time) 
		, sample_count = count(*)
		, snapshot_time = @snapshot_time_new
		, snapshot_type_id = @snapshot_type_id
		, sql_instance = @sql_instance
	from [dbo].sqlwatch_logger_dm_os_performance_counters pc
	
	where pc.snapshot_time > @start
		and @snapshot_type_id is not null --to make sure we have valid timer for this snapshot
	
	group by  
		pc.[performance_counter_id]
		, pc.[instance_name]
		, pc.[sql_instance]  
	end;

--declare		@snapshot_time datetime2(0),
--			@first_snapshot_time datetime2(0), 
--			@last_snapshot_time datetime2(0),
--			@snapshot_time_utc_offset int

--  select 
--	  @first_snapshot_time =min(snapshot_time)
--	, @last_snapshot_time=max(snapshot_time)
--	, @snapshot_time_utc_offset = max(snapshot_time_utc_offset)
--  from [dbo].[sqlwatch_logger_snapshot_header] h
--  where datepart(hour,h.snapshot_time) = datepart(hour,dateadd(hour,-1,getutcdate()))
--  and datepart(day,h.snapshot_time) = datepart(day,dateadd(hour,-1,getutcdate()))
--  and datepart(month,h.snapshot_time) = datepart(month,dateadd(hour,-1,getutcdate()))
--  and datepart(year,h.snapshot_time) = datepart(year,dateadd(hour,-1,getutcdate()))

--  insert into [dbo].[sqlwatch_trend_logger_dm_os_performance_counters] (
--		performance_counter_id
--		, instance_name
--		, sql_instance
--		, cntr_value_calculated_avg
--		, cntr_value_calculated_min
--		, cntr_value_calculated_max
--		, cntr_value_calculated_sum
--		, interval_minutes
--		, snapshot_time
--		, snapshot_time_offset
--		, valid_until
--		)
--  select pc.[performance_counter_id]
--      ,pc.[instance_name]
--      ,pc.[sql_instance]
--      ,[cntr_value_calculated_avg] = avg(pc.[cntr_value_calculated])
--	  ,[cntr_value_calculated_min] = min(pc.[cntr_value_calculated])
--	  ,[cntr_value_calculated_max] = max(pc.[cntr_value_calculated])
--	  ,[cntr_value_calculated_sum] = sum(pc.[cntr_value_calculated])
--	  ,[interval_minutes] = @interval_minutes --datediff(minute,@first_snapshot_time,@last_snapshot_time)
--	  , snapshot_time = dateadd(minute, datediff(minute, 0, h.snapshot_time ) / @interval_minutes * @interval_minutes, 0)
--	  ,[snapshot_time_offset] = TODATETIMEOFFSET ( dateadd(minute, datediff(minute, 0, h.snapshot_time ) / @interval_minutes * @interval_minutes, 0) , h.snapshot_time_utc_offset )  
--		/*
--	  , snapshot_time = dateadd(hour, datediff(hour, 0, h.snapshot_time), 0)
--	  ,[snapshot_time_offset] = TODATETIMEOFFSET ( dateadd(hour, datediff(hour, 0, h.snapshot_time), 0) , h.snapshot_time_utc_offset )  
--		*/
--	   , valid_until = dateadd(day,@valid_days,getutcdate())
--  from [dbo].[sqlwatch_logger_dm_os_performance_counters] pc
  
--  inner join [dbo].[sqlwatch_logger_snapshot_header] h
--	on pc.sql_instance = h.sql_instance
--	and pc.snapshot_time = h.snapshot_time
--	and pc.snapshot_type_id = pc.snapshot_type_id

--  inner join [dbo].[sqlwatch_meta_dm_os_performance_counters] mpc
--	on mpc.performance_counter_id = pc.performance_counter_id
--	and mpc.sql_instance = pc.sql_instance

--  left join [dbo].[sqlwatch_trend_logger_dm_os_performance_counters] t
--	on t.snapshot_time = dateadd(minute, datediff(minute, 0, h.snapshot_time ) / @interval_minutes * @interval_minutes, 0)
--	and t.[instance_name] = pc.[instance_name]
--	and t.[sql_instance] = pc.[sql_instance]
--	and t.[interval_minutes] = @interval_minutes
--	and t.[performance_counter_id] = pc.[performance_counter_id]

--  where mpc.cntr_type <> 1073939712  --exclude base counters
--  and h.snapshot_time >= @first_snapshot_time
--  and h.snapshot_time <= @last_snapshot_time
--  and pc.sql_instance = dbo.ufn_sqlwatch_get_servername()
--  and (	
--			t.snapshot_time is null
--		and	t.instance_name is null
--		and t.sql_instance is null
--		and t.interval_minutes is null
--		and t.performance_counter_id is null
--		)

--  group by  pc.[performance_counter_id]
--      ,pc.[instance_name]
--      ,pc.[sql_instance]  
--	  , dateadd(minute, datediff(minute, 0, h.snapshot_time ) / @interval_minutes * @interval_minutes, 0)
--	  , TODATETIMEOFFSET ( dateadd(minute, datediff(minute, 0, h.snapshot_time ) / @interval_minutes * @interval_minutes, 0) , h.snapshot_time_utc_offset )  
