CREATE TABLE [dbo].[sqlwatch_meta_plan_handle]
(
	sql_instance varchar(32) not null,
	[plan_handle] varbinary(64) not null,
	[query_plan] xml null,
	date_first_seen datetime,
	date_last_seen datetime,

	constraint pk_sqlwatch_meta_plan_handle primary key clustered (
		sql_instance, [plan_handle]
	),

	constraint fk_sqlwatch_meta_plan_handle_servername foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)