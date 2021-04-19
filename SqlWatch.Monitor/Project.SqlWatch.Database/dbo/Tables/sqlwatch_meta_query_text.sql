CREATE TABLE [dbo].[sqlwatch_meta_query_text]
(
	sqlwatch_query_id int identity(1,1) not null,
	[sql_instance] varchar(32) not null,
	[sql_handle] varbinary(64) not null,
	[query_hash] varbinary(8) null,
	sql_text varchar(max) null,
	date_first_seen datetime,
	date_last_seen datetime,

	constraint pk_sqlwatch_logger_meta_sql_handle primary key clustered (
		sql_instance, sqlwatch_query_id
	),

	constraint fk_sqlwatch_meta_sql_handle_servername foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
go

create unique nonclustered index idx_sqlwatch_meta_sql_handle_handle
	on [dbo].[sqlwatch_meta_query_text] ([sql_handle])