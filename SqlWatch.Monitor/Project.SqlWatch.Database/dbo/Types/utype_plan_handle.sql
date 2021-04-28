CREATE TYPE [dbo].[utype_plan_handle] AS TABLE
(
	plan_handle varbinary(64),
	statement_start_offset int,
	statement_end_offset int,
	[sql_handle] varbinary(64) null
)
