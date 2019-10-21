CREATE VIEW [dbo].[vw_sqlwatch_report_disk_utilisation_volume] with schemabinding
as

SELECT uv.[sqlwatch_volume_id]
      ,[volume_free_space_bytes]
      ,[volume_total_space_bytes]
      ,[report_time] = convert(smalldatetime,[snapshot_time])
      ,uv.[sql_instance]
  FROM [dbo].[sqlwatch_logger_disk_utilisation_volume] uv