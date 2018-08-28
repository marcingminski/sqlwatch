CREATE VIEW [dbo].[vw_sql_perf_mon_wait_stats_categorised] as
	select ws.* , category_name = case when ws.wait_type like 'PREEMPTIVE%' then 'PREEMPTIVE' else wt.category_name end , wt.ignore
	from [dbo].[sql_perf_mon_wait_stats] ws
	left join [dbo].[sql_perf_mon_config_wait_stats] wt
	on ws.wait_type LIKE wt.wait_type
