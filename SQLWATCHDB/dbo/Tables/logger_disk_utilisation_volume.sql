CREATE TABLE [dbo].[logger_disk_utilisation_volume]
(
	[volume_name] nvarchar(255) not null,
	[volume_label] nvarchar(255),
	[volume_fs] varchar(255),
	[volume_block_size_bytes] int,
	[volume_free_space_bytes] bigint,
	[volume_total_space_bytes] bigint,
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint,
	constraint PK_disk_util_vol primary key clustered (
		snapshot_time, volume_name
		),
	constraint FK_disk_util_vol_snapshot_header foreign key ([snapshot_time],[snapshot_type_id]) references [dbo].[sql_perf_mon_snapshot_header]([snapshot_time],[snapshot_type_id]) on delete cascade
)
