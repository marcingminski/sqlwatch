CREATE VIEW [dbo].[vw_sqlwatch_report_dim_database] with schemabinding
as 
	select [database_name], [database_create_date], [sql_instance], [sqlwatch_database_id], [deleted_when] 
		,pbi_sqlwatch_database_id = sql_instance + '.DB.' + convert(varchar(10),sqlwatch_database_id)
	from dbo.sqlwatch_meta_database
