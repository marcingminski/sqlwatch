CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_disk_utilisation_os_volume]
	@volume_name nvarchar(255),
	@volume_free_space_bytes bigint,
	@volume_total_space_bytes bigint
as

declare @snapshot_type_id smallint = 17
declare @snapshot_time datetime = GETUTCDATE()

insert into [dbo].[sqlwatch_logger_snapshot_header] (snapshot_time, snapshot_type_id)
values (@snapshot_time, @snapshot_type_id)		

insert into [dbo].[sqlwatch_logger_disk_utilisation_volume] (
	[sqlwatch_volume_id],
	[volume_free_space_bytes],
	[volume_total_space_bytes],
	[snapshot_time],
	[snapshot_type_id],
	[sql_instance])

select [sqlwatch_volume_id],
	[volume_free_space_bytes] = @volume_free_space_bytes,
	[volume_total_space_bytes] = @volume_total_space_bytes,
	[snapshot_time] = @snapshot_time,
	[snapshot_type_id] = @snapshot_type_id,
	[sql_instance] = ov.[sql_instance]
from [dbo].[sqlwatch_meta_os_volume] ov
where volume_name = @volume_name
and sql_instance = @@SERVERNAME
