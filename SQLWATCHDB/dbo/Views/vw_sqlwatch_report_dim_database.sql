CREATE VIEW [dbo].[vw_sqlwatch_report_dim_database] with schemabinding
as 
	select [database_name], [database_create_date], [sql_instance], [sqlwatch_database_id], [deleted_when] 
	from dbo.sqlwatch_meta_database
