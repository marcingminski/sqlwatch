CREATE VIEW [dbo].[vw_sqlwatch_internal_table_snapshot] with schemabinding
as

select [table_name] = 'sqlwatch_logger_agent_job_history', [snapshot_type_id] = 16
union all
select [table_name] = 'sqlwatch_logger_disk_utilisation_database', [snapshot_type_id] = 2
union all
select [table_name] = 'sqlwatch_logger_disk_utilisation_volume', [snapshot_type_id] = 17
union all
select [table_name] = 'sqlwatch_logger_index_missing_stats', [snapshot_type_id] = 3
union all
select [table_name] = 'sqlwatch_logger_index_usage_stats', [snapshot_type_id] = 14
union all
select [table_name] = 'sqlwatch_logger_index_histogram', [snapshot_type_id] = 15
union all
select [table_name] = 'sqlwatch_logger_perf_file_stats', [snapshot_type_id] = 1
union all
select [table_name] = 'sqlwatch_logger_perf_os_memory_clerks', [snapshot_type_id] = 1
union all
select [table_name] = 'sqlwatch_logger_perf_os_performance_counters', [snapshot_type_id] = 1
union all
select [table_name] = 'sqlwatch_logger_perf_os_process_memory', [snapshot_type_id] = 1
union all
select [table_name] = 'sqlwatch_logger_perf_os_schedulers', [snapshot_type_id] = 1
union all
select [table_name] = 'sqlwatch_logger_perf_os_wait_stats', [snapshot_type_id] = 1
union all
select [table_name] = 'sqlwatch_logger_whoisactive', [snapshot_type_id] = 11
union all
select [table_name] = 'sqlwatch_logger_xes_blockers', [snapshot_type_id] = 9
union all
select [table_name] = 'sqlwatch_logger_xes_iosubsystem', [snapshot_type_id] = 10
union all
select [table_name] = 'sqlwatch_logger_xes_long_queries', [snapshot_type_id] = 7
union all
select [table_name] = 'sqlwatch_logger_xes_query_processing',[snapshot_type_id] = 10
union all
select [table_name] = 'sqlwatch_logger_xes_waits_stats', [snapshot_type_id] = 6
union all
select [table_name] = 'sqlwatch_logger_check', [snapshot_type_id] = 18
union all
select [table_name] = 'sqlwatch_logger_check_action', [snapshot_type_id] = 18
union all
select [table_name] = 'sqlwatch_logger_disk_utilisation_table', [snapshot_type_id] = 22
