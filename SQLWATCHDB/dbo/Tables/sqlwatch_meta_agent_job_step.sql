CREATE TABLE [dbo].[sqlwatch_meta_agent_job_step]
(
	[sql_instance] nvarchar(25) not null,
	[sqlwatch_job_id] smallint not null,
	[step_name] sysname not null,
	[sqlwatch_job_step_id] smallint not null identity (-32768,1),
	constraint pk_sqlwatch_meta_agent_job_step primary key (
		[sql_instance], [sqlwatch_job_id], [sqlwatch_job_step_id]
		),
	constraint uq_sqlwatch_meta_agent_job_step_name unique (sqlwatch_job_id,step_name),
	constraint fk_sqlwatch_meta_agent_job_id foreign key ([sql_instance],[sqlwatch_job_id]) references dbo.sqlwatch_meta_agent_job([sql_instance],[sqlwatch_job_id]) on delete cascade
)
