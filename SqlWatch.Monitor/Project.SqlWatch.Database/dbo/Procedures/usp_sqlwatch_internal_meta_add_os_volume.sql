CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_meta_add_os_volume] (
	@xdoc int,
	@sql_instance varchar(32)
	)
as
begin
	set nocount on;

	select 
		volume_name,
		label,
		[file_system] = filesystem,
		[volume_block_size_bytes] = blocksize,
		[volume_free_space_bytes] = freespace,
		[volume_total_space_bytes] = capacity,
		sql_instance = @sql_instance
	into #t
	--This metadata is derived from the collection snapshot
	from openxml (@xdoc, '/CollectionSnapshot/disk_space_usage/row',1)
	with (
		[volume_name] nvarchar(255),
		[label] nvarchar(255) ,
		filesystem varchar(255),
		blocksize int,
		freespace bigint,
		capacity bigint
	)
	where volume_name not like '\\?\Volume%'
	and filesystem <> 'CDFS';

	merge [dbo].[sqlwatch_meta_os_volume] as target
	using (
		select	distinct volume_name,
				[label],
				[file_system],
				[volume_block_size_bytes],
				[sql_instance] = @sql_instance
			from #t
			) as source
	on target.[volume_name] = source.[volume_name]
	and target.[sql_instance] = source.[sql_instance]

	when matched then 
		update set [label] = source.[label],
			[file_system] = source.[file_system],
			[volume_block_size_bytes] = source.[volume_block_size_bytes],
			[date_updated] = case when 		
										target.[label] <> source.[label]
									or	target.[file_system] <> source.[file_system]
									or	target.[volume_block_size_bytes] <> source.[volume_block_size_bytes]
									then GETUTCDATE() else [date_updated] end,
			[date_last_seen] = GETUTCDATE(),
			[is_record_deleted] = 0

	when not matched by target then
		insert ([sql_instance], [volume_name], [label], [file_system], [volume_block_size_bytes], [date_created], [date_last_seen])
		values (source.[sql_instance], source.[volume_name], source.[label], source.[file_system], source.[volume_block_size_bytes], GETUTCDATE(), GETUTCDATE());

end;