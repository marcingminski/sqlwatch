CREATE TABLE [dbo].[sqlwatch_meta_sql_text]
(
	[sql_instance] varchar(32) NOT NULL,
	[sql_text_id] bigint identity(1,1) not null,
	[sql_text] nvarchar(max),
	[sql_text_hash] as HASHBYTES('MD5', [sql_text]) persisted,
	[date_created] datetime not null constraint df_sqlwatch_meta_sql_text_date_created default (getutcdate()),
	[date_last_seen] datetime,
	constraint pk_sqlwatch_meta_sql_text primary key clustered (
		[sql_instance], [sql_text_id]
		),
	constraint uq_sqlwatch_meta_sql_text_hash unique (
		[sql_text_hash]
	),
	constraint fk_sqlwatch_meta_sql_text foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
