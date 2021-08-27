CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_space_usage_os_volume]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
as
begin

	set nocount on;

	--load metadata derived from the collection snapshot:
	exec [dbo].[usp_sqlwatch_internal_meta_add_os_volume]
		@xdoc = @xdoc,
		@sql_instance = @sql_instance;

	select 
		volume_name,
		label,
		[file_system] = filesystem,
		[volume_block_size_bytes] = blocksize,
		[volume_free_space_bytes] = freespace,
		[volume_total_space_bytes] = capacity,
		sql_instance = @sql_instance
	into #t
	from openxml (@xdoc, '/CollectionSnapshot/disk_space_usage/row',1)
	with (
		[volume_name] nvarchar(255),
		[label] nvarchar(255) ,
		filesystem varchar(255),
		blocksize int,
		freespace bigint,
		capacity bigint
	);

	insert into [dbo].[sqlwatch_logger_disk_utilisation_volume] (
		[sqlwatch_volume_id],
		[volume_free_space_bytes],
		[volume_total_space_bytes],
		[snapshot_time],
		[snapshot_type_id],
		[sql_instance])

	select 
		ov.[sqlwatch_volume_id],
		t.[volume_free_space_bytes],
		t.[volume_total_space_bytes],
		[snapshot_time] = @snapshot_time,
		[snapshot_type_id] = @snapshot_type_id,
		[sql_instance] = ov.[sql_instance]
	from #t t
	inner join dbo.sqlwatch_meta_os_volume ov
		on ov.volume_name = t.volume_name
		and ov.sql_instance = @sql_instance
end;

