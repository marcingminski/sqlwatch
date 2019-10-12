while (select count(*) from [dbo].[sqlwatch_logger_perf_os_performance_counters] 
	where DATALENGTH(object_name) in ( 128, 256 )
	) > 0
		begin
			with cte_update as (
				select top 10000 * from  [dbo].[sqlwatch_logger_perf_os_performance_counters] 
				where DATALENGTH(object_name) in ( 128, 256 )
			)
			  update cte_update
				set [object_name] = rtrim([object_name])
				, [instance_name] = rtrim([instance_name])
				, [counter_name] = rtrim([counter_name])
		end