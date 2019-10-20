CREATE VIEW [dbo].[vw_sqlwatch_report_perf_os_wait_stats] with schemabinding
as
  with cte_waits_sequence as (
	select [wait_type_id], [waiting_tasks_count], [wait_time_ms], [max_wait_time_ms], [signal_wait_time_ms], [snapshot_time], [snapshot_type_id], [sql_instance] 
		,sequence=DENSE_RANK() over (partition by sql_instance, wait_type_id order by snapshot_time) 
	from [dbo].[sqlwatch_logger_perf_os_wait_stats]
	)
  select 
	 [report_time] = convert(smalldatetime,snapshot_time)	, wait_time_ms, ms.wait_type, t.sql_instance
	 from (
		 select
			w2.snapshot_time
			,[wait_time_ms] = sum(w2.[wait_time_ms] - isnull(w1.[wait_time_ms],0)) 	
				,w2.wait_type_id
				,w2.sql_instance
		FROM cte_waits_sequence w2
		inner join cte_waits_sequence w1
			ON w1.wait_type_id = w2.wait_type_id
			and w1.snapshot_type_id = w2.snapshot_type_id
			and w1.sql_instance = w2.sql_instance
			and w1.sequence = w2.sequence - 1
		WHERE w2.wait_time_ms > 0
		GROUP BY w2.wait_type_id
			,w2.sql_instance
			,w2.snapshot_time
		HAVING sum(w2.[wait_time_ms] - isnull(w1.[wait_time_ms],0)) > 0
	) t
	inner join [dbo].[sqlwatch_meta_wait_stats] ms
		on ms.sql_instance = t.sql_instance
		and ms.wait_type_id = t.wait_type_id