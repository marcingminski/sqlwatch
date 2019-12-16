CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_disk_utilisation_os_volume]
	@volume_name nvarchar(255),
	@volume_free_space_bytes bigint,
	@volume_total_space_bytes bigint
as

declare @snapshot_type_id smallint = 17,
		@snapshot_time datetime

exec [dbo].[usp_sqlwatch_internal_insert_header] 
	@snapshot_time_new = @snapshot_time OUTPUT,
	@snapshot_type_id = @snapshot_type_id

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
