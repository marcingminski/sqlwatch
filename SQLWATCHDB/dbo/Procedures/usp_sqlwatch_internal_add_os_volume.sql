CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_os_volume] (
	@volume_name nvarchar(255),
	@label nvarchar(255),
	@file_system nvarchar(255),
	@block_size int
	)
as

merge [dbo].[sqlwatch_meta_os_volume] as target
using (
	select	volume_name = @volume_name,
			[label] = @label,
			[file_system] = @file_system,
			[volume_block_size_bytes] = @block_size,
			[sql_instance] = @@SERVERNAME
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
		[last_seen] = GETUTCDATE()

when not matched by target then
	insert ([sql_instance], [volume_name], [label], [file_system], [volume_block_size_bytes], [date_added], [last_seen])
	values (source.[sql_instance], source.[volume_name], source.[label], source.[file_system], source.[volume_block_size_bytes], GETUTCDATE(), GETUTCDATE());


