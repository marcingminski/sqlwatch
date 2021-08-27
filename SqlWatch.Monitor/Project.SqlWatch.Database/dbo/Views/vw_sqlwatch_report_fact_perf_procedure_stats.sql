CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_procedure_stats]
with schemabinding
as

select 
	  [ps].[sql_instance]
	, [ps].[sqlwatch_database_id]
	, [ps].[sqlwatch_procedure_id]
	, [ps].[snapshot_time]
	, [ps].[snapshot_type_id]
	, [ps].[cached_time]
	, [ps].[last_execution_time]
	, [ps].[execution_count]
	, [ps].[total_worker_time]
	, [ps].[min_worker_time]
	, [ps].[max_worker_time]
	, [ps].[total_physical_reads]
	, [ps].[min_physical_reads]
	, [ps].[max_physical_reads]
	, [ps].[total_logical_writes]
	, [ps].[min_logical_writes]
	, [ps].[max_logical_writes]
	, [ps].[total_logical_reads]
	, [ps].[min_logical_reads]
	, [ps].[max_logical_reads]
	, [ps].[total_elapsed_time]
	, [ps].[min_elapsed_time]
	, [ps].[max_elapsed_time]
	, [ps].[delta_worker_time]
	, [ps].[delta_physical_reads]
	, [ps].[delta_logical_writes]
	, [ps].[delta_logical_reads]
	, [ps].[delta_elapsed_time]
	, [ps].[delta_execution_count]
	, [d].[database_name]
	, [p].[procedure_name]
	, [last_execution_time_utc]
	, [cached_time_utc]
	, [cpu_time] = case when [execution_count] > 0 then total_worker_time*1.0/[execution_count] else 0 end
	, [physical_reads] = case when [execution_count] > 0 then [total_physical_reads]*1.0/[execution_count] else 0 end
	, [logical_reads] = case when [execution_count] > 0 then [total_logical_reads]*1.0/[execution_count] else 0 end
	, [logical_writes] = case when [execution_count] > 0 then [total_logical_writes]*1.0/[execution_count] else 0 end
	, [elapsed_time] = case when [execution_count] > 0 then total_elapsed_time*1.0/[execution_count] else 0 end
	, [elapsed_time_ms] = case when [execution_count] > 0 then total_elapsed_time*1.0/[execution_count] / 1000 else 0 end
from [dbo].[sqlwatch_logger_dm_exec_procedure_stats] ps

inner join [dbo].[sqlwatch_meta_procedure] p
	on p.sqlwatch_procedure_id = ps.sqlwatch_procedure_id
	and p.sqlwatch_database_id = ps.sqlwatch_database_id
	and p.sql_instance = ps.sql_instance

inner join [dbo].[sqlwatch_meta_database] d 
	on p.sql_instance = d.sql_instance 
	and p.sqlwatch_database_id = d.sqlwatch_database_id;