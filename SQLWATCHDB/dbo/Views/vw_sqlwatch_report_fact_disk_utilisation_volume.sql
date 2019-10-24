CREATE VIEW [dbo].[vw_sqlwatch_report_fact_disk_utilisation_volume] with schemabinding
as

SELECT uv.[sqlwatch_volume_id]
      ,[volume_free_space_bytes]
      ,[volume_total_space_bytes]
      ,sh.report_time
      ,uv.[sql_instance]
	  ,pbi_os_volume_id = uv.sql_instance + '.DISK.' + convert(varchar(10),uv.[sqlwatch_volume_id])
  FROM [dbo].[sqlwatch_logger_disk_utilisation_volume] uv
  	inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = uv.sql_instance
		and sh.snapshot_time = uv.[snapshot_time]
		and sh.snapshot_type_id = uv.snapshot_type_id