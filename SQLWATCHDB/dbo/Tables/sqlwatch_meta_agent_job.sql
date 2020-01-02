CREATE TABLE [dbo].[sqlwatch_meta_agent_job]
(
	[sql_instance] varchar(32) not null,
	[job_name] nvarchar(128) not null,
	[job_create_date] datetime not null,
	[sqlwatch_job_id] smallint identity(1,1),
	[date_last_seen] datetime null constraint df_sqlwatch_meta_agent_job_last_seen default (getutcdate()),
	[is_record_deleted] bit
	constraint pk_sqlwatch_meta_agent_job primary key (
		[sql_instance], [sqlwatch_job_id]
		),
	constraint uq_sqlwatch_meta_agent_job_name unique([sql_instance],[job_name],[job_create_date])   ,
	constraint fk_sqlwatch_meta_agent_job_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)