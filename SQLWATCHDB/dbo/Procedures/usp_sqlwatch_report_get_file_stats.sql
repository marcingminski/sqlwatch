CREATE PROCEDURE [dbo].[usp_sqlwatch_report_get_file_stats]
(
	@interval_minutes smallint = null,
	@report_window int = null,
	@report_end_time datetime = null,
	@sql_instance nvarchar(25) = null
	)
as

   SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

if @report_window is null
set @report_window = 4

if @report_end_time is null
set @report_end_time= getutcdate()

select 
	@interval_minutes  = case when @interval_minutes  is null then report_time_interval_minutes else @interval_minutes end
from [dbo].[ufn_sqlwatch_time_intervals](1,@interval_minutes,@report_window,@report_end_time)

   select /* SQLWATCH Power BI fn_get_file_statistics */
		[report_time] = s.[snapshot_interval_end]
		,fs2.[sqlwatch_master_file_id]
                ,fs2.[sqlwatch_database_id]
                ,[logical_file_name] = mf.[file_name]
                ,mf.[logical_disk]
                ,mf.[file_type]
		,[num_of_mb_transferred_delta] = ((fs2.[num_of_bytes_read] - fs1.[num_of_bytes_read]) + (fs2.[num_of_bytes_written] - fs1.[num_of_bytes_written])) / 1024.0 / 1024.0
		,[io_stall_ms_delta] = ((fs2.[io_stall_read_ms] - fs1.[io_stall_read_ms]) + (fs2.io_stall_write_ms - fs1.io_stall_write_ms))
		,[io_num_of_readswrites] = ((fs2.num_of_reads - fs1.num_of_reads) + (fs2.num_of_writes - fs1.num_of_writes)) 
		,[io_latency_ms] = case when ((fs2.num_of_reads - fs1.num_of_reads) + (fs2.num_of_writes - fs1.num_of_writes)) <= 0 then 0 else ((fs2.[io_stall_read_ms] - fs1.[io_stall_read_ms]) + (fs2.io_stall_write_ms - fs1.io_stall_write_ms)) / ((fs2.num_of_reads - fs1.num_of_reads) + (fs2.num_of_writes - fs1.num_of_writes)) end
                ,[io_num_of_reads_delta]=fs2.num_of_reads - fs1.num_of_reads
                ,[io_num_of_writes_delta]=fs2.num_of_writes - fs1.num_of_writes
                ,[io_stall_read_ms_delta]=fs2.[io_stall_read_ms] - fs1.[io_stall_read_ms]
                ,[io_stall_write_ms_delta]=fs2.io_stall_write_ms - fs1.io_stall_write_ms
                ,[io_latency_ms_read] = case when (fs2.num_of_reads - fs1.num_of_reads) <= 0 then 0 else ((fs2.[io_stall_read_ms] - fs1.[io_stall_read_ms])) / ((fs2.num_of_reads - fs1.num_of_reads)) end
                ,[io_latency_ms_write] = case when (fs2.num_of_writes - fs1.num_of_writes) <= 0 then 0 else ((fs2.[io_stall_write_ms] - fs1.[io_stall_write_ms])) / ((fs2.num_of_writes - fs1.num_of_writes)) end
                ,[num_of_mb_read_delta] = ((fs2.[num_of_bytes_read] - fs1.[num_of_bytes_read]) ) / 1024.0 / 1024.0
                ,[num_of_mb_written_delta] = ((fs2.[num_of_bytes_written] - fs1.[num_of_bytes_written])) / 1024.0 / 1024.0
                ,[size_on_disk_mb]=fs2.[size_on_disk_bytes]/ 1024.0 / 1024.0
                ,[size_on_disk_mb_delta]=(fs2.[size_on_disk_bytes]-fs1.[size_on_disk_bytes]) / 1024.0 / 1024.0
                ,s.[snapshot_type_id]
                ,s.sql_instance
                ,[is_latest] = case when fs2.[snapshot_time] = (
					select max(t.snapshot_time) 
					from [dbo].[sqlwatch_logger_snapshot_header] t
					where t.snapshot_type_id = fs2.snapshot_type_id) then 1 else 0 end
    from [dbo].[sqlwatch_logger_perf_file_stats]  fs1

        inner join [dbo].[ufn_sqlwatch_time_intervals](1,@interval_minutes,@report_window,@report_end_time) s
			on fs1.snapshot_time = s.first_snapshot_time
                        and fs1.snapshot_type_id = s.snapshot_type_id
                        and fs1.sql_instance = s.sql_instance

	inner join [dbo].[sqlwatch_logger_perf_file_stats]  fs2 
		on fs1.[sqlwatch_database_id] = fs2.[sqlwatch_database_id] 
		and fs1.[sqlwatch_master_file_id] = fs2.[sqlwatch_master_file_id]
		and fs2.snapshot_time = s.last_snapshot_time
                and fs2.snapshot_type_id = fs1.snapshot_type_id
                and fs2.sql_instance = fs1.sql_instance

	inner join [dbo].[sqlwatch_meta_master_file] mf
                on  mf.[sqlwatch_master_file_id] = fs2.[sqlwatch_master_file_id]
                and mf.sql_instance = fs2.sql_instance
                
	where mf.deleted_when is null
	and fs2.sql_instance = isnull(@sql_instance,fs2.sql_instance)