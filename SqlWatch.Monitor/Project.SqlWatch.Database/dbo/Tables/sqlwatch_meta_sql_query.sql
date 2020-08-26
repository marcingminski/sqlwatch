CREATE TABLE [dbo].[sqlwatch_meta_sql_query]
(
	[sql_instance] varchar(32) NOT NULL,
	[sqlwatch_query_hash] varbinary(16) not null,
	[sql_text] nvarchar(max),
	[date_first_seen] datetime not null,
	[date_last_seen] datetime not null
	constraint pk_sqlwatch_meta_sql_text primary key clustered (
		[sql_instance], [sqlwatch_query_hash]
		),
	constraint fk_sqlwatch_meta_sql_text foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
go