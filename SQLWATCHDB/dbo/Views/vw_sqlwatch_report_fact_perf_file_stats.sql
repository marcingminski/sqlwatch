CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_file_stats] WITH SCHEMABINDING
AS


 /* The performance gains of LAG function are significant but it make it not compatible with SQL2008 as this is introduced in SQL2012. */
 with cte_file_stats_lag as (
	 SELECT [sqlwatch_database_id]
		  ,[sqlwatch_master_file_id]
		  ,[num_of_reads]
		  ,[num_of_bytes_read]
		  ,[io_stall_read_ms]
		  ,[num_of_writes]
		  ,[num_of_bytes_written]
		  ,[io_stall_write_ms]
		  ,[size_on_disk_bytes]
		  ,[snapshot_time]
		  ,[sql_instance]
		  ,[num_of_reads_prev] = lag([num_of_reads]) over (partition by sql_instance, [sqlwatch_database_id], [sqlwatch_master_file_id] order by snapshot_time)
		  ,[num_of_bytes_read_prev] = lag([num_of_bytes_read]) over (partition by sql_instance, [sqlwatch_database_id], [sqlwatch_master_file_id] order by snapshot_time)
		  ,[io_stall_read_ms_prev] = lag([io_stall_read_ms]) over (partition by sql_instance, [sqlwatch_database_id], [sqlwatch_master_file_id] order by snapshot_time)
		  ,[num_of_writes_prev] = lag([num_of_writes]) over (partition by sql_instance, [sqlwatch_database_id], [sqlwatch_master_file_id] order by snapshot_time)
		  ,[num_of_bytes_written_prev] = lag([num_of_bytes_written]) over (partition by sql_instance, [sqlwatch_database_id], [sqlwatch_master_file_id] order by snapshot_time)
		  ,[io_stall_write_ms_prev] = lag([io_stall_write_ms]) over (partition by sql_instance, [sqlwatch_database_id], [sqlwatch_master_file_id] order by snapshot_time)
		  ,[size_on_disk_bytes_prev] = lag([size_on_disk_bytes]) over (partition by sql_instance, [sqlwatch_database_id], [sqlwatch_master_file_id] order by snapshot_time)
		  ,[snapshot_time_prev] = lag([snapshot_time]) over (partition by sql_instance, [sqlwatch_database_id], [sqlwatch_master_file_id] order by snapshot_time)
	  FROM [dbo].[sqlwatch_logger_perf_file_stats]
  )
  select 
		 [report_time] = convert(smalldatetime,snapshot_time)
		,[sqlwatch_master_file_id]
        ,[sqlwatch_database_id]
		,[num_of_mb_transferred_delta] = (([num_of_bytes_read] - [num_of_bytes_read_prev]) + ([num_of_bytes_written] - [num_of_bytes_written_prev])) / 1024.0 / 1024.0
		,[io_stall_ms_delta] = (([io_stall_read_ms] - [io_stall_read_ms_prev]) + (io_stall_write_ms - io_stall_write_ms_prev))
		,[io_num_of_readswrites] = ((num_of_reads - num_of_reads_prev) + (num_of_writes - num_of_writes_prev)) 
		,[io_latency_ms] = case when ((num_of_reads - num_of_reads_prev) + (num_of_writes - num_of_writes_prev)) <= 0 then 0 else (([io_stall_read_ms] - [io_stall_read_ms_prev]) + (io_stall_write_ms - io_stall_write_ms_prev)) / ((num_of_reads -  num_of_reads_prev) + (num_of_writes -  num_of_writes_prev)) end
                ,[io_num_of_reads_delta]=num_of_reads - num_of_reads_prev
                ,[io_num_of_writes_delta]=num_of_writes - num_of_writes_prev
                ,[io_stall_read_ms_delta]=[io_stall_read_ms] - [io_stall_read_ms_prev]
                ,[io_stall_write_ms_delta]=io_stall_write_ms - io_stall_write_ms_prev
                ,[io_latency_ms_read] = case when (num_of_reads - num_of_reads_prev) <= 0 then 0 else (([io_stall_read_ms] - [io_stall_read_ms_prev])) / ((num_of_reads - num_of_reads_prev)) end
                ,[io_latency_ms_write] = case when (num_of_writes - num_of_writes_prev) <= 0 then 0 else (([io_stall_write_ms] - [io_stall_write_ms_prev])) / ((num_of_writes - num_of_writes_prev)) end
                ,[num_of_mb_read_delta] = (([num_of_bytes_read] - [num_of_bytes_read_prev]) ) / 1024.0 / 1024.0
                ,[num_of_mb_written_delta] = (([num_of_bytes_written] - [num_of_bytes_written_prev])) / 1024.0 / 1024.0
                ,[size_on_disk_mb]=[size_on_disk_bytes]/ 1024.0 / 1024.0
                ,[size_on_disk_mb_delta]=([size_on_disk_bytes]-[size_on_disk_bytes_prev]) / 1024.0 / 1024.0
                ,sql_instance
    from cte_file_stats_lag
	where [snapshot_time_prev] is not null


	/* without LAG we would have to figure our row sequence and self join */

 --with cte_file_stats_sequence as (
	--select [sqlwatch_database_id], [sqlwatch_master_file_id], [num_of_reads], [num_of_bytes_read], [io_stall_read_ms], [num_of_writes], [num_of_bytes_written]
	--	 , [io_stall_write_ms], [size_on_disk_bytes], [snapshot_time], [snapshot_type_id], [sql_instance] 
	--	 , sequence=DENSE_RANK() over (partition by sql_instance, [sqlwatch_database_id], [sqlwatch_master_file_id] order by snapshot_time desc)
	--from [dbo].[sqlwatch_logger_perf_file_stats]
	--)
 --select 
	--	[report_time] = convert(smalldatetime,fs2.snapshot_time)
	--	,fs2.[sqlwatch_master_file_id]
 --               ,fs2.[sqlwatch_database_id]
 --               --,[logical_file_name] = mf.[file_name]
 --               --,mf.[logical_disk]
 --               --,mf.[file_type]
	--	,[num_of_mb_transferred_delta] = ((fs2.[num_of_bytes_read] - fs1.[num_of_bytes_read]) + (fs2.[num_of_bytes_written] - fs1.[num_of_bytes_written])) / 1024.0 / 1024.0
	--	,[io_stall_ms_delta] = ((fs2.[io_stall_read_ms] - fs1.[io_stall_read_ms]) + (fs2.io_stall_write_ms - fs1.io_stall_write_ms))
	--	,[io_num_of_readswrites] = ((fs2.num_of_reads - fs1.num_of_reads) + (fs2.num_of_writes - fs1.num_of_writes)) 
	--	,[io_latency_ms] = case when ((fs2.num_of_reads - fs1.num_of_reads) + (fs2.num_of_writes - fs1.num_of_writes)) <= 0 then 0 else ((fs2.[io_stall_read_ms] - fs1.[io_stall_read_ms]) + (fs2.io_stall_write_ms - fs1.io_stall_write_ms)) / ((fs2.num_of_reads - fs1.num_of_reads) + (fs2.num_of_writes - fs1.num_of_writes)) end
 --               ,[io_num_of_reads_delta]=fs2.num_of_reads - fs1.num_of_reads
 --               ,[io_num_of_writes_delta]=fs2.num_of_writes - fs1.num_of_writes
 --               ,[io_stall_read_ms_delta]=fs2.[io_stall_read_ms] - fs1.[io_stall_read_ms]
 --               ,[io_stall_write_ms_delta]=fs2.io_stall_write_ms - fs1.io_stall_write_ms
 --               ,[io_latency_ms_read] = case when (fs2.num_of_reads - fs1.num_of_reads) <= 0 then 0 else ((fs2.[io_stall_read_ms] - fs1.[io_stall_read_ms])) / ((fs2.num_of_reads - fs1.num_of_reads)) end
 --               ,[io_latency_ms_write] = case when (fs2.num_of_writes - fs1.num_of_writes) <= 0 then 0 else ((fs2.[io_stall_write_ms] - fs1.[io_stall_write_ms])) / ((fs2.num_of_writes - fs1.num_of_writes)) end
 --               ,[num_of_mb_read_delta] = ((fs2.[num_of_bytes_read] - fs1.[num_of_bytes_read]) ) / 1024.0 / 1024.0
 --               ,[num_of_mb_written_delta] = ((fs2.[num_of_bytes_written] - fs1.[num_of_bytes_written])) / 1024.0 / 1024.0
 --               ,[size_on_disk_mb]=fs2.[size_on_disk_bytes]/ 1024.0 / 1024.0
 --               ,[size_on_disk_mb_delta]=(fs2.[size_on_disk_bytes]-fs1.[size_on_disk_bytes]) / 1024.0 / 1024.0
 --               ,fs2.sql_instance
	--			,[is_latest] = case when fs2.sequence = 1 then 1 else 0 end
 --    --           ,[is_latest] = case when fs2.[snapshot_time] = (
	--				--select max(t.snapshot_time) 
	--				--from [dbo].[sqlwatch_logger_snapshot_header] t
	--				--where t.snapshot_type_id = fs2.snapshot_type_id
	--				--and t.sql_instance = fs2.sql_instance) then 1 else 0 end
	--			--,mdb.[database_name]
	--			--,mf.file_physical_name
 --   from cte_file_stats_sequence  fs1

	--inner join cte_file_stats_sequence  fs2 
	--	on fs1.[sqlwatch_database_id] = fs2.[sqlwatch_database_id] 
	--	and fs1.[sqlwatch_master_file_id] = fs2.[sqlwatch_master_file_id]
	--	and fs1.sequence = fs2.sequence + 1
 --               and fs2.snapshot_type_id = fs1.snapshot_type_id
 --               and fs2.sql_instance = fs1.sql_instance

	----inner join [dbo].[sqlwatch_meta_master_file] mf
 ----               on  mf.[sqlwatch_master_file_id] = fs2.[sqlwatch_master_file_id]
 ----               and mf.sql_instance = fs2.sql_instance

	----inner join [dbo].[sqlwatch_meta_database] mdb
	----	on mdb.sql_instance = mf.sql_instance
	----	and mdb.sqlwatch_database_id = mf.sqlwatch_database_id
                
	----where mf.deleted_when is null