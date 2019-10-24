CREATE VIEW [dbo].[vw_sqlwatch_report_dim_index_missing] with schemabinding
	AS 
	select [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_missing_index_id], [equality_columns], [inequality_columns], [included_columns], [statement]
	, [index_handle], [date_added], [date_updated], [date_deleted] 

		,pbi_sqlwatch_database_id = sql_instance + '.DB.' + convert(varchar(10),sqlwatch_database_id)
		,pbi_sqlwatch_table_id = sql_instance + '.DB.' + convert(varchar(10),sqlwatch_database_id) + '.TBL.' + convert(varchar(10),[sqlwatch_table_id])
		,pbi_sqlwatch_missing_index_id = sql_instance + '.DB.' + convert(varchar(10),sqlwatch_database_id) + '.TBL.' + convert(varchar(10),[sqlwatch_table_id]) +'.MIDX.' + convert(varchar(10),sqlwatch_missing_index_id)

	from dbo.sqlwatch_meta_index_missing
