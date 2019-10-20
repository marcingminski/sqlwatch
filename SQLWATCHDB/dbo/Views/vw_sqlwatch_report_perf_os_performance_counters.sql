CREATE VIEW [dbo].[vw_sqlwatch_report_perf_os_performance_counters] with schemabinding
as

 with cte_counters as (
	select performance_counter_id
		  ,[instance_name]
		  ,[cntr_value]
		  ,[base_cntr_value]
		  ,[snapshot_time]
		  ,pc.[sql_instance]
		  ,[sequence] = dense_rank() over (partition by pc.sql_instance, performance_counter_id, instance_name order by snapshot_time)
	  from [dbo].[sqlwatch_logger_perf_os_performance_counters] pc
	)
	select 
		  pc2.sql_instance
		 ,report_time = convert(smalldatetime,pc2.snapshot_time)
		 ,[object_name] = rtrim(ltrim(mc.[object_name]))
		 ,[instance_name] = case when rtrim(ltrim(mc.[object_name])) = 'win32_perfformatteddata_perfos_processor' and rtrim(ltrim(mc.counter_name)) = 'Processor Time %' and rtrim(ltrim(isnull(pc2.instance_name, ''))) = 'system' then 'os' 
            else rtrim(ltrim(pc2.instance_name)) end
		, [counter_name] = rtrim(ltrim(mc.counter_name))
		,[cntr_value] = convert(real,(
			case 
				when mc.object_name = 'Batch Resp Statistics' then case when pc2.cntr_value > pc.cntr_value then cast((pc2.cntr_value - pc.cntr_value) as real) else 0 end -- delta absolute
				when mc.cntr_type = 65792 then isnull(pc.cntr_value,0) -- point-in-time
				when mc.cntr_type = 272696576 then case when (pc2.cntr_value > pc.cntr_value) then (pc2.cntr_value - pc.cntr_value) / cast(datediff(second,pc.snapshot_time,pc2.snapshot_time) as real) else 0 end -- delta rate
				when mc.cntr_type = 537003264 then isnull(cast(100.0 as real) * pc.cntr_value / nullif(pc2.cntr_value, 0),0) -- ratio
				when mc.cntr_type = 1073874176 then isnull(case when pc2.cntr_value > pc.cntr_value then isnull((pc2.cntr_value - pc.cntr_value) / nullif(pc2.cntr_value - pc.base_cntr_value, 0) / cast(datediff(second,pc.snapshot_time,pc2.snapshot_time) as real), 0) else 0 end,0) -- delta ratio
			end))
		, mdb.sqlwatch_database_id
from cte_counters as pc

inner join cte_counters pc2
	on pc.sql_instance = pc2.sql_instance
	and pc.performance_counter_id = pc2.performance_counter_id
	and pc.[sequence] = pc2.[sequence] - 1
	and pc.instance_name = pc2.instance_name

  inner join [dbo].[sqlwatch_meta_performance_counter] mc
	on pc2.[sql_instance] = mc.[sql_instance]
	and pc2.[performance_counter_id] = mc.[performance_counter_id]

  left join [dbo].[sqlwatch_meta_database] mdb
	on mdb.sql_instance = pc2.sql_instance
	and mdb.database_name = pc2.instance_name

where mc.cntr_type in (272696576,1073874176,65792,537003264)

 