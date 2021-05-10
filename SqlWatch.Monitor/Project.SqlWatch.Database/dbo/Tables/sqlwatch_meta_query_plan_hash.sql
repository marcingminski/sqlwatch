CREATE TABLE [dbo].[sqlwatch_meta_query_plan_hash]
(
	[sql_instance] varchar(32) not null,
	[query_plan_hash] varbinary(8) not null, --constraint df_sqlwatch_meta_query_plan_query_plan_hash default 0x00000000,
	[query_plan_for_query_plan_hash] nvarchar(max) null,
	--< to be removed in next Major
	[statement_start_offset] int null,
	[statement_end_offset] int null,
	--to be removed in next Major >
	[statement_for_query_plan_hash] varchar(max) null,
	[date_first_seen] datetime,
	[date_last_seen] datetime,

	constraint pk_sqlwatch_meta_plan_handle primary key clustered (
		sql_instance, [query_plan_hash] --, [statement_start_offset], [statement_end_offset]
	),

	--cannot have a constraint to plan_handle as we are storing query plans at the hash level.
	--multiple handles across different databases may have the same hash.
	--constraint fk_sqlwatch_meta_plan_handle
	--	foreign key (sql_instance, [plan_handle], [query_plan_hash], [statement_start_offset], [statement_end_offset])
	--	references [dbo].[sqlwatch_meta_query_plan_handle] (sql_instance, [plan_handle], [query_plan_hash], [statement_start_offset], [statement_end_offset]) 
	--	on delete cascade
);