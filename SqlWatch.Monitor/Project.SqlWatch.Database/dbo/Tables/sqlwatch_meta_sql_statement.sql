CREATE TABLE [dbo].[sqlwatch_meta_sql_statement]
(
	[sql_instance] varchar(32) NOT NULL,
	[sqlwatch_sql_text_hash] varbinary(16) not null,
	[query_hash] decimal(20,0) not null,
	[sql_statement] nvarchar(max),
	[date_first_seen] datetime not null,
	[date_last_seen] datetime not null,
	[times_seen] bigint,
	constraint pk_sqlwatch_meta_sql_statement primary key clustered (
		[sql_instance], [sqlwatch_sql_text_hash], [query_hash]
		),

	constraint fk_sqlwatch_meta_sql_statement_sql_text 
		foreign key ([sql_instance],[sqlwatch_sql_text_hash])
		references [dbo].[sqlwatch_meta_sql_query] ([sql_instance],[sqlwatch_query_hash])
		on delete cascade		
)
go