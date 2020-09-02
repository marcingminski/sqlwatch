CREATE TABLE [dbo].[sqlwatch_meta_sql_handle]
(
	sql_instance varchar(32) not null,
	[sql_handle] varbinary(64) not null,
	sql_text varchar(max) null,
	date_first_seen datetime,
	date_last_seen datetime,

	constraint pk_sqlwatch_logger_meta_sql_handle primary key clustered (
		sql_instance, [sql_handle]
	),

	constraint fk_sqlwatch_meta_sql_handle_servername foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)