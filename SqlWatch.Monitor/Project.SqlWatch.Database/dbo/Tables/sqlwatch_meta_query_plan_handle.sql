CREATE TABLE [dbo].[sqlwatch_meta_query_plan_handle]
(
	-- this is a "helper" table to link plans stored in [dbo].[sqlwatch_meta_query_plan]
	-- based on handles and offset. without this table it would be difficult to match plans as some source (like xes) do not provide query hash in binary format
	-- when we get data from xes, the only way to get plan via plan_handle and statement offset
	sql_instance varchar(32) not null,
	[plan_handle] varbinary(64) not null,
	[sql_handle] varbinary(64) not null,
	[query_hash] varbinary(8) not null,
	[query_plan_hash] varbinary(8) not null,
	[statement_start_offset] int not null,
	[statement_end_offset] int not null,
	[date_updated] datetime2(0) not null,


	constraint pk_sqlwatch_meta_query_plan_handle
		primary key (sql_instance, [plan_handle], [statement_start_offset], [statement_end_offset])

	--this needs an FK or a trigger to handle deletions when plans are deleted
)
