CREATE VIEW [dbo].[vw_sqlwatch_report_dim_table] with schemabinding
	AS 
	select [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [table_name], [table_type], [date_created], [date_updated], [date_deleted] 
	from dbo.sqlwatch_meta_table
