CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_dm_io_virtual_file_stats]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32),
	@snapshot_time_previous datetime2(0)
AS
begin

	set nocount on;

	declare @prev_fs table (
		[sqlwatch_database_id] smallint null,
		[sqlwatch_master_file_id] smallint null,
		[snapshot_time] datetime2(0) null,
		[snapshot_type_id] tinyint null ,
		[sql_instance] varchar(32) null ,

		[num_of_reads] real null,
		[num_of_bytes_read] real null,
		[io_stall_read_ms] real null,
		[num_of_writes] real null,
		[num_of_bytes_written] real null,
		[io_stall_write_ms] real null,
		[size_on_disk_bytes] real null
	);

	insert into @prev_fs (
		  [sqlwatch_database_id]
		, [sqlwatch_master_file_id]
		, [snapshot_time]
		, [snapshot_type_id]
		, [sql_instance]

		, num_of_reads
		, num_of_bytes_read 
		, io_stall_read_ms 
		, num_of_writes 
		, num_of_bytes_written 
		, io_stall_write_ms 
		, size_on_disk_bytes
	)
	select 
		  prevfs.[sqlwatch_database_id]
		, prevfs.[sqlwatch_master_file_id]
		, prevfs.[snapshot_time]
		, prevfs.[snapshot_type_id]
		, prevfs.[sql_instance]
		
		, prevfs.num_of_reads
		, prevfs.num_of_bytes_read 
		, prevfs.io_stall_read_ms 
		, prevfs.num_of_writes 
		, prevfs.num_of_bytes_written 
		, prevfs.io_stall_write_ms 
		, prevfs.size_on_disk_bytes
	from [dbo].[sqlwatch_logger_dm_io_virtual_file_stats] (nolock) prevfs
	where prevfs.sql_instance = @sql_instance
		and prevfs.snapshot_type_id = @snapshot_type_id
		and prevfs.snapshot_time = @snapshot_time_previous
	option (keep plan);

	insert into dbo.[sqlwatch_logger_dm_io_virtual_file_stats] (
		[sqlwatch_database_id]
		,[sqlwatch_master_file_id]
		,[num_of_reads],[num_of_bytes_read],[io_stall_read_ms],[num_of_writes],[num_of_bytes_written],[io_stall_write_ms],[size_on_disk_bytes]
		,[snapshot_time]
		,[snapshot_type_id]
		,[sql_instance]
		,[num_of_reads_delta]
		,[num_of_bytes_read_delta]
		,[io_stall_read_ms_delta]
		,[num_of_writes_delta]
		,[num_of_bytes_written_delta]
		,[io_stall_write_ms_delta]
		,[size_on_disk_bytes_delta]
		,[delta_seconds]
		)
	select 
		 sd.sqlwatch_database_id
		, mf.sqlwatch_master_file_id
		, num_of_reads = convert(real,fs.num_of_reads)
		, num_of_bytes_read = convert(real,fs.num_of_bytes_read)
		, io_stall_read_ms = convert(real,fs.io_stall_read_ms)
		, num_of_writes = convert(real,fs.num_of_writes)
		, num_of_bytes_written = convert(real,fs.num_of_bytes_written)
		, io_stall_write_ms = convert(real,fs.io_stall_write_ms)
		, size_on_disk_bytes = convert(real,fs.size_on_disk_bytes)
		, snapshot_time=@snapshot_time
		, snapshot_type_id = @snapshot_type_id
		, sql_instance = @sql_instance

		, [num_of_reads_delta] = convert(real,case when fs.num_of_reads > prevfs.num_of_reads then fs.num_of_reads - prevfs.num_of_reads else 0 end)
		, [num_of_bytes_read_delta] = convert(real,case when fs.num_of_bytes_read > prevfs.num_of_bytes_read then fs.num_of_bytes_read - prevfs.num_of_bytes_read else 0 end)
		, [io_stall_read_ms_delta] = convert(real,case when fs.io_stall_read_ms > prevfs.io_stall_read_ms then fs.io_stall_read_ms - prevfs.io_stall_read_ms else 0 end)
		, [num_of_writes_delta]= convert(real,case when fs.num_of_writes > prevfs.num_of_writes then fs.num_of_writes - prevfs.num_of_writes else 0 end)
		, [num_of_bytes_written_delta] = convert(real,case when fs.num_of_bytes_written > prevfs.num_of_bytes_written then fs.num_of_bytes_written - prevfs.num_of_bytes_written else 0 end)
		, [io_stall_write_ms_delta] = convert(real,case when fs.io_stall_write_ms > prevfs.io_stall_write_ms then fs.io_stall_write_ms - prevfs.io_stall_write_ms else 0 end)
		, [size_on_disk_bytes_delta] = convert(real,case when fs.size_on_disk_bytes > prevfs.size_on_disk_bytes then fs.size_on_disk_bytes - prevfs.size_on_disk_bytes else 0 end)
		, [delta_seconds] = datediff(second,@snapshot_time_previous,@snapshot_time)

	from openxml (@xdoc, '/CollectionSnapshot/dm_io_virtual_file_stats/row',1) 
	with (
		[database_name] sysname
		,database_create_date datetime2(3)
		,[num_of_reads] bigint
		,[num_of_bytes_read] bigint
		,[io_stall_read_ms] bigint
		,[num_of_writes] bigint
		,[num_of_bytes_written] bigint
		,[io_stall_write_ms] bigint
		,[size_on_disk_bytes] bigint
		,[physical_name] nvarchar(260)
		,[file_name] nvarchar(128)
	) fs

	inner join [dbo].[sqlwatch_meta_database] sd 
		on sd.[database_name] = fs.[database_name] collate database_default
		and sd.[database_create_date] = fs.database_create_date
		and sd.sql_instance = @sql_instance

	inner join [dbo].[sqlwatch_meta_master_file] mf
		on mf.sql_instance = @sql_instance
		and mf.sqlwatch_database_id = sd.sqlwatch_database_id
		and mf.file_name = fs.file_name
		and mf.[file_physical_name] = fs.physical_name

	left join @prev_fs prevfs
		on prevfs.sql_instance = @sql_instance
		and prevfs.sqlwatch_database_id = mf.sqlwatch_database_id
		and prevfs.sqlwatch_master_file_id = mf.sqlwatch_master_file_id
	option (maxdop 1, keep plan);
end;