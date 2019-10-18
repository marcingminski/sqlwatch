CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_get_last_snapshot_time_in_tables]
	@sql_instance nvarchar(25) = null
as

declare @sql varchar(max)
declare @tmptable nvarchar(255)
set @tmptable = replace(convert(varchar(255),newid()),'-','')


set @sql = '
if object_id(''tempdb..##' + @tmptable + ''') is null
	begin 
		create table ##' + @tmptable + ' (
			sql_instance nvarchar(25),
			table_name nvarchar(255),
			snapshot_time datetime
		)
	end;'

select @sql = @sql + '
insert into ##' +  @tmptable+ '
select sql_instance, table_name=''' + T.TABLE_NAME  + ''', snapshot_time=max(snapshot_time) from ' + T.TABLE_SCHEMA + '.' + T.TABLE_NAME + '
' + case when nullif(@sql_instance,'') is not null then ' where sql_instance=''' +@sql_instance+ '''' else '' end + '
group by sql_instance;'
		FROM INFORMATION_SCHEMA.TABLES T
		INNER JOIN INFORMATION_SCHEMA.COLUMNS C
			ON T.TABLE_CATALOG = C.TABLE_CATALOG
			AND T.TABLE_SCHEMA = C.TABLE_SCHEMA
			AND T.TABLE_NAME = C.TABLE_NAME
		WHERE C.COLUMN_NAME = 'snapshot_time'
		AND T.TABLE_TYPE = 'BASE TABLE'

print @sql
exec (@sql)

/* coverting datetime to varchar because stupid ssis does not understand miliseconds in DateTime variables. */

set @sql = '
select sql_instance
,[sqlwatch_logger_agent_job_history] = convert(varchar(23),isnull([sqlwatch_logger_agent_job_history],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_disk_utilisation_database] = convert(varchar(23),isnull([sqlwatch_logger_disk_utilisation_database],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_disk_utilisation_volume] = convert(varchar(23),isnull([sqlwatch_logger_disk_utilisation_volume],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_index_missing_stats] = convert(varchar(23),isnull([sqlwatch_logger_index_missing_stats],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_index_usage_stats] = convert(varchar(23),isnull([sqlwatch_logger_index_usage_stats],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_index_usage_stats_histogram] = convert(varchar(23),isnull([sqlwatch_logger_index_usage_stats_histogram],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_perf_file_stats] = convert(varchar(23),isnull([sqlwatch_logger_perf_file_stats],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_perf_os_memory_clerks] = convert(varchar(23),isnull([sqlwatch_logger_perf_os_memory_clerks],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_perf_os_performance_counters] = convert(varchar(23),isnull([sqlwatch_logger_perf_os_performance_counters],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_perf_os_process_memory] = convert(varchar(23),isnull([sqlwatch_logger_perf_os_process_memory],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_perf_os_schedulers] = convert(varchar(23),isnull([sqlwatch_logger_perf_os_schedulers],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_perf_os_wait_stats] = convert(varchar(23),isnull([sqlwatch_logger_perf_os_wait_stats],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_whoisactive] = convert(varchar(23),isnull([sqlwatch_logger_whoisactive],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_xes_blockers] = convert(varchar(23),isnull([sqlwatch_logger_xes_blockers],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_xes_iosubsystem] = convert(varchar(23),isnull([sqlwatch_logger_xes_iosubsystem],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_xes_long_queries] = convert(varchar(23),isnull([sqlwatch_logger_xes_long_queries],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_xes_query_processing] = convert(varchar(23),isnull([sqlwatch_logger_xes_query_processing],''1970-01-01 00:00:00''),121)
,[sqlwatch_logger_xes_waits_stats] = convert(varchar(23),isnull([sqlwatch_logger_xes_waits_stats],''1970-01-01 00:00:00''),121)
from (
	select sql_instance, table_name, snapshot_time
	from ##' + @tmptable + ' ) p
pivot (
	max(snapshot_time)
	for table_name in 
	(	 [sqlwatch_logger_agent_job_history]
		,[sqlwatch_logger_disk_utilisation_database]
		,[sqlwatch_logger_disk_utilisation_volume]
		,[sqlwatch_logger_index_missing_stats]
		,[sqlwatch_logger_index_usage_stats]
		,[sqlwatch_logger_index_usage_stats_histogram]
		,[sqlwatch_logger_perf_file_stats]
		,[sqlwatch_logger_perf_os_memory_clerks]
		,[sqlwatch_logger_perf_os_performance_counters]
		,[sqlwatch_logger_perf_os_process_memory]
		,[sqlwatch_logger_perf_os_schedulers]
		,[sqlwatch_logger_perf_os_wait_stats]
		,[sqlwatch_logger_whoisactive]
		,[sqlwatch_logger_xes_blockers]
		,[sqlwatch_logger_xes_iosubsystem]
		,[sqlwatch_logger_xes_long_queries]
		,[sqlwatch_logger_xes_query_processing]
		,[sqlwatch_logger_xes_waits_stats]
	)) as pvt
	'

exec (@sql) with result sets (
 (		 sql_instance nvarchar(25),
		 [sqlwatch_logger_agent_job_history] varchar(23)
		,[sqlwatch_logger_disk_utilisation_database] varchar(23)
		,[sqlwatch_logger_disk_utilisation_volume] varchar(23)
		,[sqlwatch_logger_index_missing_stats] varchar(23)
		,[sqlwatch_logger_index_usage_stats] varchar(23)
		,[sqlwatch_logger_index_usage_stats_histogram] varchar(23)
		,[sqlwatch_logger_perf_file_stats] varchar(23)
		,[sqlwatch_logger_perf_os_memory_clerks] varchar(23)
		,[sqlwatch_logger_perf_os_performance_counters] varchar(23)
		,[sqlwatch_logger_perf_os_process_memory] varchar(23)
		,[sqlwatch_logger_perf_os_schedulers] varchar(23)
		,[sqlwatch_logger_perf_os_wait_stats] varchar(23)
		,[sqlwatch_logger_whoisactive] varchar(23)
		,[sqlwatch_logger_xes_blockers] varchar(23)
		,[sqlwatch_logger_xes_iosubsystem] varchar(23)
		,[sqlwatch_logger_xes_long_queries] varchar(23)
		,[sqlwatch_logger_xes_query_processing] varchar(23)
		,[sqlwatch_logger_xes_waits_stats] varchar(23))
)