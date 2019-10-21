CREATE VIEW [dbo].[vw_sqlwatch_report_dim_master_file] with schemabinding
	AS 
	select [sqlwatch_database_id], [sqlwatch_master_file_id], [file_id], [file_type], [file_name], [file_physical_name], [sql_instance], [deleted_when], [logical_disk] 
	from dbo.sqlwatch_meta_master_file
