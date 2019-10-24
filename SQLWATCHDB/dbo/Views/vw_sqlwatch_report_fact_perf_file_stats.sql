CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_file_stats] WITH SCHEMABINDING
AS

select [sqlwatch_database_id], [sqlwatch_master_file_id], [num_of_reads], [num_of_bytes_read], [io_stall_read_ms], [num_of_writes], [num_of_bytes_written]
, [io_stall_write_ms], [size_on_disk_bytes], report_time, d.[sql_instance], [num_of_reads_delta], [num_of_bytes_read_delta]
, [io_stall_read_ms_delta], [num_of_writes_delta], [num_of_bytes_written_delta], [io_stall_write_ms_delta], [size_on_disk_bytes_delta], [delta_seconds]
, pbi_sqlwatch_master_file_id = d.sql_instance + '.DB.' + convert(varchar(10),d.sqlwatch_database_id) + '.MF.' + convert(varchar(10),d.[sqlwatch_master_file_id])
	  FROM [dbo].[sqlwatch_logger_perf_file_stats] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

