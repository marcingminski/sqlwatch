CREATE VIEW [dbo].[vw_sqlwatch_report_fact_disk_utilisation_volume] with schemabinding
as

SELECT d.[sqlwatch_volume_id]
      ,[volume_free_space_bytes]
      ,[volume_total_space_bytes]
      ,h.report_time
      ,d.[sql_instance]
	  ,pbi_os_volume_id = d.sql_instance + '.DISK.' + convert(varchar(10),d.[sqlwatch_volume_id])
  FROM [dbo].[sqlwatch_logger_disk_utilisation_volume] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance