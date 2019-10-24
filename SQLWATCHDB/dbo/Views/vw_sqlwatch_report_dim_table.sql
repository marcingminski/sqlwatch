CREATE VIEW [dbo].[vw_sqlwatch_report_dim_table] with schemabinding
	AS 
	select [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [table_name], [table_type], [date_added], [date_updated], [date_deleted] 
		,pbi_sqlwatch_database_id = sql_instance + '.DB.' + convert(varchar(10),sqlwatch_database_id)
		,pbi_sqlwatch_table_id = sql_instance + '.DB.' + convert(varchar(10),sqlwatch_database_id) + '.TBL.' + convert(varchar(10),[sqlwatch_table_id])
	from dbo.sqlwatch_meta_table
