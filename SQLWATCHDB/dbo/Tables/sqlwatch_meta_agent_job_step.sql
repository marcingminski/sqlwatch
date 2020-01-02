CREATE TABLE [dbo].[sqlwatch_meta_agent_job_step]
(
	[sql_instance] varchar(32) not null,
	[sqlwatch_job_id] smallint not null ,
	[step_name] nvarchar(128) not null,
	[sqlwatch_job_step_id] int identity(1,1),
	[date_last_seen] datetime null constraint df_sqlwatch_meta_agent_job_step_last_seen default (getutcdate()),
	[is_record_deleted] bit
	constraint pk_sqlwatch_meta_agent_job_step primary key (
		[sql_instance], [sqlwatch_job_id], [sqlwatch_job_step_id]
		),
	constraint uq_sqlwatch_meta_agent_job_step_name unique ([sql_instance], [sqlwatch_job_id],step_name),
	constraint fk_sqlwatch_meta_agent_job_id foreign key ([sql_instance],[sqlwatch_job_id]) references dbo.sqlwatch_meta_agent_job([sql_instance],[sqlwatch_job_id]) on delete cascade
)
