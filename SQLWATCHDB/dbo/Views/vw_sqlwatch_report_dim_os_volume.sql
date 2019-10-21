CREATE VIEW [dbo].[vw_sqlwatch_report_dim_os_volume] with schemabinding
	AS 
	select [sql_instance], [sqlwatch_volume_id], [volume_name], [label], [file_system], [volume_block_size_bytes], [date_added], [date_updated], [last_seen] 
	from dbo.sqlwatch_meta_os_volume
