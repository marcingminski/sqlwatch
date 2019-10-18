declare @sql varchar(max)
declare @sql_instance nvarchar(25) = 'dummy'

drop table if exists ##9E9ADFD64D9844F8BF7F446D6B386108 
create table ##9E9ADFD64D9844F8BF7F446D6B386108 (
	table_name nvarchar(255),
	snapshot_time datetime
)

set @sql = ''
SELECT @sql = @sql + '
insert into ##9E9ADFD64D9844F8BF7F446D6B386108
select table_name=''' + T.TABLE_SCHEMA + '.' + T.TABLE_NAME  + ''', snapshot_time=isnull(max(snapshot_time),''1970-01-01'') from ' + T.TABLE_SCHEMA + '.' + T.TABLE_NAME + '
where sql_instance = ''' +@sql_instance+ ''';'
		FROM INFORMATION_SCHEMA.TABLES T
		INNER JOIN INFORMATION_SCHEMA.COLUMNS C
			ON T.TABLE_CATALOG = C.TABLE_CATALOG
			AND T.TABLE_SCHEMA = C.TABLE_SCHEMA
			AND T.TABLE_NAME = C.TABLE_NAME
		WHERE C.COLUMN_NAME = 'snapshot_time'

print @sql
exec (@sql)


select [dbo.sqlwatch_logger_agent_job_history]
,[dbo.sqlwatch_logger_disk_utilisation_database]
,[dbo.sqlwatch_logger_disk_utilisation_volume]
,[dbo.sqlwatch_logger_index_missing_stats]
,[dbo.sqlwatch_logger_index_usage_stats]
,[dbo.sqlwatch_logger_index_usage_stats_histogram]
,[dbo.sqlwatch_logger_perf_file_stats]
,[dbo.sqlwatch_logger_perf_os_memory_clerks]
,[dbo.sqlwatch_logger_perf_os_performance_counters]
,[dbo.sqlwatch_logger_perf_os_process_memory]
,[dbo.sqlwatch_logger_perf_os_schedulers]
,[dbo.sqlwatch_logger_perf_os_wait_stats]
,[dbo.sqlwatch_logger_snapshot_header]
,[dbo.sqlwatch_logger_whoisactive]
,[dbo.sqlwatch_logger_xes_blockers]
,[dbo.vw_sqlwatch_report_perf_os_performance_counters]
,[dbo.vw_sqlwatch_report_perf_os_wait_stats]
,[dbo.sqlwatch_logger_xes_iosubsystem]
,[dbo.sqlwatch_logger_xes_long_queries]
,[dbo.sqlwatch_logger_xes_query_processing]
,[dbo.sqlwatch_logger_xes_waits_stats]
from (
	select table_name, snapshot_time
	from ##9E9ADFD64D9844F8BF7F446D6B386108 ) p
pivot (
	max(snapshot_time)
	for table_name in 
	(	[dbo.sqlwatch_logger_agent_job_history]
		,[dbo.sqlwatch_logger_disk_utilisation_database]
		,[dbo.sqlwatch_logger_disk_utilisation_volume]
		,[dbo.sqlwatch_logger_index_missing_stats]
		,[dbo.sqlwatch_logger_index_usage_stats]
		,[dbo.sqlwatch_logger_index_usage_stats_histogram]
		,[dbo.sqlwatch_logger_perf_file_stats]
		,[dbo.sqlwatch_logger_perf_os_memory_clerks]
		,[dbo.sqlwatch_logger_perf_os_performance_counters]
		,[dbo.sqlwatch_logger_perf_os_process_memory]
		,[dbo.sqlwatch_logger_perf_os_schedulers]
		,[dbo.sqlwatch_logger_perf_os_wait_stats]
		,[dbo.sqlwatch_logger_snapshot_header]
		,[dbo.sqlwatch_logger_whoisactive]
		,[dbo.sqlwatch_logger_xes_blockers]
		,[dbo.vw_sqlwatch_report_perf_os_performance_counters]
		,[dbo.vw_sqlwatch_report_perf_os_wait_stats]
		,[dbo.sqlwatch_logger_xes_iosubsystem]
		,[dbo.sqlwatch_logger_xes_long_queries]
		,[dbo.sqlwatch_logger_xes_query_processing]
		,[dbo.sqlwatch_logger_xes_waits_stats]
	)) as pvt