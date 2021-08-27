CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_os_performance_counters_rate] with schemabinding
as

with cte_pivot as (
	select sql_instance, snapshot_time, report_time, snapshot_type_id
		, [Full Scan Rate] = case when [Index Searches/sec] > 0 then [Full Scans/sec] / [Index Searches/sec] else 0 end
		, [SQL Compilations Rate] = case when [Batch Requests/Sec] > 0 then [SQL Compilations/sec] / [Batch Requests/Sec] else 0 end
		, [SQL Re-Compilation Rate] = case when [SQL Compilations/sec] > 0 then [SQL Re-Compilations/sec] / [SQL Compilations/sec] else 0 end
		, [Page Split Rate] = case when [Batch Requests/Sec] > 0 then [Page Splits/sec] / [Batch Requests/Sec] else 0 end
		, [Page Lookups Rate] = case when [Batch Requests/Sec] > 0 then [Page lookups/sec] / [Batch Requests/Sec] else 0 end
	from  
	(	
		select sql_instance, snapshot_time, counter_name, cntr_value_calculated, report_time, snapshot_type_id
		from [dbo].[vw_sqlwatch_report_fact_perf_os_performance_counters]
	) as src  
	pivot  
	(  
	avg(cntr_value_calculated)  
	for counter_name IN (
		  [Index Searches/sec]
		, [Full Scans/sec]
		, [SQL Compilations/sec]
		, [Batch Requests/Sec]
		, [SQL Re-Compilations/sec]
		, [Page Splits/sec]
		, [Page lookups/sec]
		)  
	) as pvt
)

select [sql_instance]
	, [snapshot_time]
	, [cntr_value_calculated]
	, [counter_name]
	, [report_time]
	, snapshot_type_id
from 
   (select [sql_instance]
	, [snapshot_time]
	, [Full Scan Rate]
	, [SQL Compilations Rate]
	, [SQL Re-Compilation Rate]
	, [Page Split Rate]
	, [Page Lookups Rate]
	, [report_time]
	, snapshot_type_id
   from cte_pivot) p  
unpivot  
   (cntr_value_calculated for counter_name IN   
      (	  
		  [Full Scan Rate]
		, [SQL Compilations Rate]
		, [SQL Re-Compilation Rate]
		, [Page Split Rate]
		, [Page Lookups Rate]
		)  
) as unpvt;  
GO