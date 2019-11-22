CREATE VIEW [dbo].[vw_sqlwatch_report_dim_index_missing] with schemabinding
	AS 
	select [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_missing_index_id], [equality_columns], [inequality_columns], [included_columns], [statement]
	, [index_handle], [date_created], [date_updated], [date_deleted] 
	from dbo.sqlwatch_meta_index_missing
