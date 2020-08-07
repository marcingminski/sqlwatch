while (select count(*) from [dbo].[sqlwatch_logger_perf_os_performance_counters] 
	where DATALENGTH([performance_counter_id]) in ( 128, 256 )
	) > 0
		begin
			with cte_update as (
				select top 10000 * from  [dbo].[sqlwatch_logger_perf_os_performance_counters] 
				where DATALENGTH([performance_counter_id]) in ( 128, 256 )
			)
			  update cte_update
				set [performance_counter_id] = rtrim([performance_counter_id])
				, [instance_name] = rtrim([instance_name])
				, [counter_name] = rtrim([counter_name])
		end


--REBUILD INDEXES AFTER THE SCRIPT HAS FINISHED