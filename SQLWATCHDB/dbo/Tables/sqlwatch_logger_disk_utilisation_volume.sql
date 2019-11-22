CREATE TABLE [dbo].[sqlwatch_logger_disk_utilisation_volume]
(
	[sqlwatch_volume_id] smallint not null ,
	[volume_free_space_bytes] bigint,
	[volume_total_space_bytes] bigint,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_disk_utilisation_volume_sql_instance default (@@SERVERNAME),
	constraint PK_disk_util_vol primary key clustered (
		snapshot_time, [snapshot_type_id], [sql_instance], [sqlwatch_volume_id]
		),
	constraint fk_sqlwatch_logger_disk_utilisation_volume_id foreign key ([sql_instance], [sqlwatch_volume_id]) references [dbo].[sqlwatch_meta_os_volume] ([sql_instance], [sqlwatch_volume_id]) on delete cascade,
	constraint FK_disk_util_vol_snapshot_header foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) on delete cascade on update cascade
)
