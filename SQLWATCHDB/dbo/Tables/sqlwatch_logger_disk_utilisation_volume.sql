CREATE TABLE [dbo].[sqlwatch_logger_disk_utilisation_volume]
(
	[volume_name] nvarchar(255) not null,
	[volume_label] nvarchar(255),
	[volume_fs] varchar(255),
	[volume_block_size_bytes] int,
	[volume_free_space_bytes] bigint,
	[volume_total_space_bytes] bigint,
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,
	constraint PK_disk_util_vol primary key clustered (
		snapshot_time, [snapshot_type_id], [sql_instance], volume_name
		),
	constraint FK_disk_util_vol_snapshot_header foreign key ([snapshot_time],[snapshot_type_id],[sql_instance]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id],[sql_instance]) on delete cascade on update cascade
)
