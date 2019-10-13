CREATE VIEW [dbo].[vw_sqlwatch_report_perf_os_performance_counters] with schemabinding
as

select mc.[object_name]
	  ,mc.[counter_name]
      ,[instance_name]
      ,[cntr_value]
      ,[base_cntr_value]
	  ,mc.[cntr_type]
      ,[snapshot_time]
      ,[snapshot_type_id]
      ,pc.[sql_instance]
  from [dbo].[sqlwatch_logger_perf_os_performance_counters] pc
  inner join [dbo].[sqlwatch_meta_performance_counter] mc
	on pc.[sql_instance] = mc.[sql_instance]
	and pc.[performance_counter_id] = mc.[performance_counter_id]