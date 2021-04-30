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
	, [ps].[last_worker_time]
	, [ps].[min_worker_time]
	, [ps].[max_worker_time]
	, [ps].[total_physical_reads]
	, [ps].[last_physical_reads]
	, [ps].[min_physical_reads]
	, [ps].[max_physical_reads]
	, [ps].[total_logical_writes]
	, [ps].[last_logical_writes]
	, [ps].[min_logical_writes]
	, [ps].[max_logical_writes]
	, [ps].[total_logical_reads]
	, [ps].[last_logical_reads]
	, [ps].[min_logical_reads]
	, [ps].[max_logical_reads]
	, [ps].[total_elapsed_time]
	, [ps].[last_elapsed_time]
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
	, [last_execution_time_utc]=[dbo].[ufn_sqlwatch_convert_time_utc]([last_execution_time])
	, [cached_time_utc]=[dbo].[ufn_sqlwatch_convert_time_utc]([cached_time])
	, [cpu_time] = delta_worker_time*1.0/delta_execution_count
	, [physical_reads] = [delta_physical_reads]*1.0/delta_execution_count
	, [logical_reads] = [delta_logical_reads]*1.0/delta_execution_count
	, [logical_writes] = [delta_logical_writes]*1.0/delta_execution_count
	, [elapsed_time] = delta_elapsed_time/delta_execution_count

from [dbo].[sqlwatch_logger_perf_procedure_stats] ps

inner join [dbo].[sqlwatch_meta_procedure] p
	on p.sqlwatch_procedure_id = ps.sqlwatch_procedure_id
	and p.sqlwatch_database_id = ps.sqlwatch_database_id
	and p.sql_instance = ps.sql_instance

inner join [dbo].[sqlwatch_meta_database] d 
	on p.sql_instance = d.sql_instance 
	and p.sqlwatch_database_id = d.sqlwatch_database_id



