CREATE TABLE [dbo].[sqlwatch_meta_query_plan]
(
	[sqlwatch_query_plan_id] int identity(1,1) not null,
	[sqlwatch_query_id] int not null,
	[sql_instance] varchar(32) not null,
	[plan_handle] varbinary(64) not null,
	[query_plan_hash] varbinary(8) null,
	[query_plan] xml null,
	[date_first_seen] datetime,
	[date_last_seen] datetime,

	--single query can have multiple plans
	constraint pk_sqlwatch_meta_plan_handle primary key clustered (
		sql_instance, sqlwatch_query_plan_id, [sqlwatch_query_id]
	),

	--constraint fk_sqlwatch_meta_plan_handle_servername foreign key ([sql_instance])
	--	references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade,

	constraint fk_sqlwatwch_meta_query_text 
		foreign key (sql_instance, sqlwatch_query_id)
		references [dbo].[sqlwatch_meta_query_text] on delete cascade
)
go

create unique nonclustered index idx_sqlwatch_meta_query_plan_hanlde
	on [dbo].[sqlwatch_meta_query_plan] ([plan_handle], [sql_instance])