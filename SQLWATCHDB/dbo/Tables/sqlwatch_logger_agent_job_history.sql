CREATE TABLE [dbo].[sqlwatch_logger_agent_job_history]
(
	[sql_instance] nvarchar(25) not null,
	[sqlwatch_job_id] uniqueidentifier,
	[sqlwatch_job_step_id] uniqueidentifier,
	[sysjobhistory_instance_id] int not null,
	[sysjobhistory_step_id] int not null,
	[run_duration_s] int not null,
	[run_date] datetime not null,
	[run_status] tinyint not null,
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint not null,
	constraint pk_sqlwatch_logger_agent_job_history primary key (
		[sql_instance], [sqlwatch_job_id], [sqlwatch_job_step_id], [sysjobhistory_instance_id]
		),
	constraint fk_sqlwatch_logger_agent_job_history_job foreign key ([sql_instance],[sqlwatch_job_id],[sqlwatch_job_step_id]) 
		references [dbo].[sqlwatch_meta_agent_job_step] (sql_instance, [sqlwatch_job_id], sqlwatch_job_step_id) on delete cascade,
	constraint fk_sqlwatch_logger_agent_job_history_snapshot_header foreign key ([snapshot_time],[snapshot_type_id], [sql_instance]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id], [sql_instance]) on delete cascade on update cascade
)
go

create nonclustered index idx_sqlwatch_logger_agent_job_history_001 on dbo.sqlwatch_logger_agent_job_history (run_date)