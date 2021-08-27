CREATE TYPE [dbo].[utype_sqlwatch_sql_query_plan] AS TABLE
(
	query_hash varbinary(8),
	query_plan_hash varbinary(8),
	sql_text nvarchar(max),
	query_plan nvarchar(max),
	database_name nvarchar(128),
	database_create_date datetime2(3),
	procedure_name nvarchar(512)
)
