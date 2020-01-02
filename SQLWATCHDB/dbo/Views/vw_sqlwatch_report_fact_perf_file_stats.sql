CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_file_stats] WITH SCHEMABINDING
AS

select [sqlwatch_database_id], [sqlwatch_master_file_id]

, f.[database_name]
, f.[file_name]

, f.file_type
, file_type_desc = [dbo].[ufn_sqlwatch_get_file_type_desc](f.file_type)
, f.file_physical_name

, [num_of_reads], [num_of_bytes_read], [io_stall_read_ms], [num_of_writes], [num_of_bytes_written]
, [io_stall_write_ms], [size_on_disk_bytes], report_time, d.[sql_instance], [num_of_reads_delta], [num_of_bytes_read_delta]
, [io_stall_read_ms_delta], [num_of_writes_delta], [num_of_bytes_written_delta], [io_stall_write_ms_delta], [size_on_disk_bytes_delta], [delta_seconds]
, io_latency_read = case when num_of_reads_delta > 0 then [io_stall_read_ms_delta] / num_of_reads_delta else 0 end
, io_latency_write = case when [num_of_writes_delta] > 0 then [io_stall_write_ms_delta] / [num_of_writes_delta] else 0 end
, [bytes_written_per_second] = [num_of_bytes_written_delta] / [delta_seconds]
, [bytes_read_per_second] = [num_of_bytes_read_delta] / [delta_seconds]
 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, d.snapshot_time
, d.snapshot_type_id
	from [dbo].[sqlwatch_logger_perf_file_stats] d

  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

	/*  using outer apply instead of inner join is SOO MUCH slower...
		BUT it only applies to the columns we select.
		If we do not select any columns from the outer apply, it does not get applied whereas joins
		always do whether we select columns or not. 99% of the time these views will feed PowerBI wher only IDs are required
		and small subset of columns queried. that 1% will be DBAs querying views directly in SSMS (TOP (1000)) in which case, 
		having actual names instead alongisde IDs will make their life easier with small increase in performane penalty */
	outer apply (
		select file_physical_name, [file_name], file_type, mdb.[database_name]
		from dbo.sqlwatch_meta_master_file mf
		inner join [dbo].[sqlwatch_meta_database] mdb
			on mdb.sql_instance = mf.sql_instance
			and mdb.sqlwatch_database_id = mf.sqlwatch_database_id
		where mf.sqlwatch_master_file_id = d.sqlwatch_master_file_id
		and mf.sqlwatch_database_id = d.sqlwatch_database_id
		and mf.sql_instance = d.sql_instance
		) f

