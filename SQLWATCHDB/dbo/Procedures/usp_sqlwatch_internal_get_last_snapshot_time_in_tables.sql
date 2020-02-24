CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_get_last_snapshot_time_in_tables]
	@sql_instance nvarchar(25) = @@SERVERNAME
as
set nocount on;

declare @sql varchar(max)

declare @table_catalog nvarchar(128),
		@table_schema nvarchar(128),
		@table_name nvarchar(128),
		@table_type nvarchar(128)


create table #last_snapshot (
	sql_instance nvarchar(25),
	table_name nvarchar(255),
	snapshot_time datetime2(0)
)

create table #snapshot_id_table (
	table_name varchar(128),
	snapshot_type_id tinyint,
	snapshot_time datetime2(0),
	header_snapshot_time datetime2(0),
	sql_instance varchar(32)
	)

/* maintain relation between snapshots and tables */
insert into #snapshot_id_table(table_name, snapshot_type_id)
select *
from [dbo].[vw_sqlwatch_internal_table_snapshot]

update t
	--if we get null it means we have no snapshot at all.
	--at this stage this is a problem as we cannot import data without a snapshot
	--in this case, we have to default to the past to make sure no data is imported
	--to not violate referential integrity
	set header_snapshot_time = isnull(h.snapshot_time,'1970-01-01') 
		, sql_instance = @sql_instance
from #snapshot_id_table t
left join (
	select sql_instance, snapshot_type_id, snapshot_time=max(snapshot_time)
	from [dbo].[sqlwatch_logger_snapshot_header] h
	group by sql_instance, snapshot_type_id
	) h
	on h.snapshot_type_id = t.snapshot_type_id
	and h.sql_instance = @sql_instance



declare cur_tables cursor for
SELECT T.*
		FROM INFORMATION_SCHEMA.TABLES T
		INNER JOIN INFORMATION_SCHEMA.COLUMNS C
			ON T.TABLE_CATALOG = C.TABLE_CATALOG
			AND T.TABLE_SCHEMA = C.TABLE_SCHEMA
			AND T.TABLE_NAME = C.TABLE_NAME
		WHERE C.COLUMN_NAME = 'snapshot_time'
		AND T.TABLE_NAME like 'sqlwatch_logger%'
		AND T.TABLE_NAME not like 'sqlwatch_logger_snapshot_header'
		AND T.TABLE_TYPE = 'BASE TABLE'
		ORDER BY T.TABLE_NAME

open cur_tables  
fetch next from cur_tables
into @table_catalog, @table_schema,   @table_name, @table_type

while @@FETCH_STATUS = 0  
	begin
		select @sql = '
		select 
				sql_instance=''' + @sql_instance + '''
			,	table_name=''' + @table_name  + '''
			,   snapshot_time =max(snapshot_time)
			from ' + @table_name + ' h
			where h.sql_instance = ''' + @sql_instance + '''
'
		--print @sql
		insert into #last_snapshot
		exec (@sql)
		fetch next from cur_tables
		into @table_catalog, @table_schema,   @table_name, @table_type
	end



update t
	set snapshot_time = s.snapshot_time
from #snapshot_id_table t
	inner join #last_snapshot s
	on t.table_name = s.table_name

set @sql = ''
select @sql = @sql + ',' + table_name + ' = max(case when table_name = '''+ table_name +''' then convert(varchar(23),isnull(snapshot_time,''1970-01-01 00:00:00''),121) else null end)
' +
',' + table_name + '_header = max(case when table_name = '''+ table_name +''' then convert(varchar(23),isnull(header_snapshot_time,''1970-01-01 00:00:00''),121) else null end)
' 
from #snapshot_id_table

set @sql  = 'select sql_instance 
' + @sql + '
from #snapshot_id_table
group by sql_instance'

exec (@sql) 

/*	with result sets was introduced in SQL 2012. This will not build for SQL 2008.
	Remove if building for SQL 2012.	*/
with result sets (
 (		 
	 sql_instance varchar(32)
	,sqlwatch_logger_agent_job_history varchar(23)
	,sqlwatch_logger_agent_job_history_header varchar(23)
	,sqlwatch_logger_disk_utilisation_database varchar(23)
	,sqlwatch_logger_disk_utilisation_database_header varchar(23)
	,sqlwatch_logger_disk_utilisation_volume varchar(23)
	,sqlwatch_logger_disk_utilisation_volume_header varchar(23)
	,sqlwatch_logger_index_missing_stats varchar(23)
	,sqlwatch_logger_index_missing_stats_header varchar(23)
	,sqlwatch_logger_index_usage_stats varchar(23)
	,sqlwatch_logger_index_usage_stats_header varchar(23)
	,sqlwatch_logger_index_histogram varchar(23)
	,sqlwatch_logger_index_histogram_header varchar(23)
	,sqlwatch_logger_perf_file_stats varchar(23)
	,sqlwatch_logger_perf_file_stats_header varchar(23)
	,sqlwatch_logger_perf_os_memory_clerks varchar(23)
	,sqlwatch_logger_perf_os_memory_clerks_header varchar(23)
	,sqlwatch_logger_perf_os_performance_counters varchar(23)
	,sqlwatch_logger_perf_os_performance_counters_header varchar(23)
	,sqlwatch_logger_perf_os_process_memory varchar(23)
	,sqlwatch_logger_perf_os_process_memory_header varchar(23)
	,sqlwatch_logger_perf_os_schedulers varchar(23)
	,sqlwatch_logger_perf_os_schedulers_header varchar(23)
	,sqlwatch_logger_perf_os_wait_stats varchar(23)
	,sqlwatch_logger_perf_os_wait_stats_header varchar(23)
	,sqlwatch_logger_whoisactive varchar(23)
	,sqlwatch_logger_whoisactive_header varchar(23)
	,sqlwatch_logger_xes_blockers varchar(23)
	,sqlwatch_logger_xes_blockers_header varchar(23)
	,sqlwatch_logger_xes_iosubsystem varchar(23)
	,sqlwatch_logger_xes_iosubsystem_header varchar(23)
	,sqlwatch_logger_xes_long_queries varchar(23)
	,sqlwatch_logger_xes_long_queries_header varchar(23)
	,sqlwatch_logger_xes_query_processing varchar(23)
	,sqlwatch_logger_xes_query_processing_header varchar(23)
	,sqlwatch_logger_xes_waits_stats varchar(23)
	,sqlwatch_logger_xes_waits_stats_header varchar(23)
	,sqlwatch_logger_check varchar(23)
	,sqlwatch_logger_check_header varchar(23)
	,sqlwatch_logger_check_action varchar(23)
	,sqlwatch_logger_check_action_header varchar(23)
	,sqlwatch_logger_disk_utilisation_table varchar(23)
	,sqlwatch_logger_disk_utilisation_table_header varchar(23)
	)
)

