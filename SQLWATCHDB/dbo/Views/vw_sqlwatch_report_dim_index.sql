CREATE VIEW [dbo].[vw_sqlwatch_report_dim_index] with schemabinding
	AS 
select [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [index_name], [index_id], [index_type_desc], [date_added], [date_updated], [date_deleted]
		,pbi_sqlwatch_database_id = sql_instance + '.DB.' + convert(varchar(10),sqlwatch_database_id)
		,pbi_sqlwatch_table_id = sql_instance + '.DB.' + convert(varchar(10),sqlwatch_database_id) + '.TBL.' + convert(varchar(10),[sqlwatch_table_id])
		,pbi_sqlwatch_index_id = sql_instance + '.DB.' + convert(varchar(10),sqlwatch_database_id) + '.TBL.' + convert(varchar(10),[sqlwatch_table_id]) +'.IDX.' + convert(varchar(10),sqlwatch_index_id)
from dbo.sqlwatch_meta_index
