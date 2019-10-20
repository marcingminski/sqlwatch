CREATE VIEW [dbo].[vw_sqlwatch_report_disk_utilisation_volume] with schemabinding
as

SELECT uv.[sqlwatch_volume_id]
      ,[volume_free_space_bytes]
      ,[volume_total_space_bytes]
      ,[report_time] = convert(smalldatetime,[snapshot_time])
      ,uv.[sql_instance]
	  --,mv.file_system
	  --,mv.label
	  --,mv.last_seen
	  --,mv.volume_block_size_bytes
	  --,mv.volume_name
  FROM [dbo].[sqlwatch_logger_disk_utilisation_volume] uv

	--inner join [dbo].[sqlwatch_meta_os_volume] mv
	--	on mv.sql_instance = uv.sql_instance
	--	and mv.sqlwatch_volume_id = uv.sqlwatch_volume_id