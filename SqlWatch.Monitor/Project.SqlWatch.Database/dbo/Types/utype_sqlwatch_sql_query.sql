CREATE TYPE [dbo].[utype_sqlwatch_sql_query] AS TABLE
(
	query_hash varbinary(8),
	sql_statement nvarchar(max),
	database_name nvarchar(128),
	database_create_date datetime2(3),
	procedure_name nvarchar(512)
);