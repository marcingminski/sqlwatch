CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_os_wait_stats] with schemabinding
as
 with cte_wait_times as (
 		 select
			snapshot_time
			,[wait_time_ms]
			,[wait_time_ms_previous] = lag([wait_time_ms]) over (partition by sql_instance, wait_type_id order by snapshot_time)
			,wait_type_id
			,sql_instance
		FROM [dbo].[sqlwatch_logger_perf_os_wait_stats]
	)
 select 
	 [report_time] = convert(smalldatetime,snapshot_time)	, wait_time_ms, ms.wait_type, t.sql_instance
	 from (
		 select
			snapshot_time
			,[wait_time_ms] = sum([wait_time_ms] - isnull([wait_time_ms_previous] ,0))
				,wait_type_id
				,sql_instance
		FROM cte_wait_times
		WHERE wait_time_ms > 0
		GROUP BY wait_type_id
			,sql_instance
			,snapshot_time
		HAVING sum([wait_time_ms] - isnull([wait_time_ms_previous] ,0)) > 0
	) t
	inner join [dbo].[sqlwatch_meta_wait_stats] ms
		on ms.sql_instance = t.sql_instance
		and ms.wait_type_id = t.wait_type_id