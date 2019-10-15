CREATE PROCEDURE [dbo].[usp_sqlwatch_report_get_wait_stats]
(
	@interval_minutes smallint = null,
	@report_window int = null,
	@report_end_time datetime = null,
	@sql_instance nvarchar(25) = null
	)
as
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
     select /* SQLWATCH Power BI fn_get_wait_statistics */
	 report_time, wait_time_ms, ms.wait_type, t.sql_instance, snapshot_type_id
	 from (
		 select
			[report_time] = s.[snapshot_interval_end]  		
			,[wait_time_ms] = sum(w2.[wait_time_ms] - isnull(w1.[wait_time_ms],0)) 	
				,w2.wait_type_id
				,w2.sql_instance
				,s.snapshot_type_id
		FROM [dbo].[sqlwatch_logger_perf_os_wait_stats] w2
		INNER JOIN [dbo].[ufn_sqlwatch_time_intervals](1,@interval_minutes,@report_window,@report_end_time) s	
			on w2.snapshot_time = s.last_snapshot_time
			and w2.snapshot_type_id = s.snapshot_type_id
			and w2.sql_instance = s.sql_instance
		LEFT JOIN [dbo].[sqlwatch_logger_perf_os_wait_stats] w1
			ON w1.wait_type_id = w2.wait_type_id
			and w1.snapshot_time = s.first_snapshot_time
			and w1.snapshot_type_id = w2.snapshot_type_id
			and w1.sql_instance = w2.sql_instance
		WHERE w2.wait_time_ms > 0
			and w2.sql_instance = isnull(@sql_instance,w2.sql_instance)
		GROUP BY w2.wait_type_id
			,s.[snapshot_interval_end]
			,s.[report_time_interval_minutes]
			,[snapshot_age_hours]
			,w2.sql_instance
			,s.snapshot_type_id
		HAVING sum(w2.[wait_time_ms] - isnull(w1.[wait_time_ms],0)) > 0
	) t
	inner join [dbo].[sqlwatch_meta_wait_stats] ms
		on ms.sql_instance = t.sql_instance
		and ms.wait_type_id = t.wait_type_id