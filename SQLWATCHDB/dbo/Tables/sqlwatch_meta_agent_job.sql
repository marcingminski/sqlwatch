CREATE TABLE [dbo].[sqlwatch_meta_agent_job]
(
	[sql_instance] nvarchar(25) not null,
	[job_name] nvarchar(128) not null,
	[job_create_date] datetime not null,
	[sqlwatch_job_id] uniqueidentifier not null default newsequentialid(),
	[deleted_when] datetime null,
	constraint pk_sqlwatch_meta_agent_job primary key (
		[sql_instance], [sqlwatch_job_id]
		),
	constraint uq_sqlwatch_meta_agent_job_name unique([sql_instance],[job_name],[job_create_date])   ,
	constraint fk_sqlwatch_meta_agent_job_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)