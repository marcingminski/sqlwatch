CREATE VIEW [dbo].[vw_sqlwatch_report_dim_master_file] with schemabinding
	AS 
		select [d].[sqlwatch_database_id], [d].[sqlwatch_master_file_id], [d].[file_id]
		, [d].[file_type]

		, file_type_desc = [dbo].[ufn_sqlwatch_get_file_type_desc](d.file_type)
		, [d].[file_name], [d].[file_physical_name], [d].[sql_instance], [d].[date_last_seen], [d].[logical_disk], lg.size_on_disk_bytes
		, [is_record_deleted]

		from [dbo].[sqlwatch_meta_master_file] d

			outer apply (
				select [f].[sqlwatch_database_id], [f].[sqlwatch_master_file_id], [f].[num_of_reads], [f].[num_of_bytes_read], [f].[io_stall_read_ms], [f].[num_of_writes], [f].[num_of_bytes_written], [f].[io_stall_write_ms], [f].[size_on_disk_bytes], [f].[snapshot_time], [f].[snapshot_type_id], [f].[sql_instance], [f].[num_of_reads_delta], [f].[num_of_bytes_read_delta], [f].[io_stall_read_ms_delta], [f].[num_of_writes_delta], [f].[num_of_bytes_written_delta], [f].[io_stall_write_ms_delta], [f].[size_on_disk_bytes_delta], [f].[delta_seconds], h.first_snapshot_time, h.last_snapshot_time
				from [dbo].[sqlwatch_logger_perf_file_stats] f
				inner join (
					select sql_instance
						, snapshot_type_id
						, first_snapshot_time=min(snapshot_time)
						, last_snapshot_time=max(snapshot_time) 
					from [dbo].[sqlwatch_logger_snapshot_header]
					group by sql_instance, snapshot_type_id
				) h
					on h.sql_instance = f.sql_instance
					and h.snapshot_type_id = f.snapshot_type_id
					and h.last_snapshot_time = f.snapshot_time
				where f.sql_instance = d.sql_instance
				and f.sqlwatch_master_file_id = d.sqlwatch_master_file_id
				and f.sqlwatch_database_id = d.sqlwatch_database_id
				) vc

			--outer apply (
			--	select g1.*
			--	from [dbo].[sqlwatch_logger_perf_file_stats] g1
			--	where g1.sql_instance = d.sql_instance
			--	and snapshot_time = vc.first_snapshot_time
			--	and g1.sqlwatch_database_id = vc.sqlwatch_database_id
			--	) fg

			outer apply (
				select [g2].[sqlwatch_database_id], [g2].[sqlwatch_master_file_id], [g2].[num_of_reads], [g2].[num_of_bytes_read], [g2].[io_stall_read_ms]
					, [g2].[num_of_writes], [g2].[num_of_bytes_written], [g2].[io_stall_write_ms], [g2].[size_on_disk_bytes], [g2].[snapshot_time]
					, [g2].[snapshot_type_id], [g2].[sql_instance], [g2].[num_of_reads_delta], [g2].[num_of_bytes_read_delta], [g2].[io_stall_read_ms_delta]
					, [g2].[num_of_writes_delta], [g2].[num_of_bytes_written_delta], [g2].[io_stall_write_ms_delta], [g2].[size_on_disk_bytes_delta]
					, [g2].[delta_seconds]
				from [dbo].[sqlwatch_logger_perf_file_stats] g2
				where g2.sql_instance = d.sql_instance
				and snapshot_time = vc.last_snapshot_time
				and g2.sqlwatch_database_id = vc.sqlwatch_database_id
				and g2.sqlwatch_master_file_id = vc.sqlwatch_master_file_id
				) lg
