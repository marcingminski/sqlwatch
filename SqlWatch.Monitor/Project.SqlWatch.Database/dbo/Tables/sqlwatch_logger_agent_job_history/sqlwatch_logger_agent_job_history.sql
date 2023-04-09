CREATE TABLE [dbo].[sqlwatch_logger_agent_job_history]
(
	[sql_instance] varchar(32) not null,
	[sqlwatch_job_id] smallint not null,
	[sqlwatch_job_step_id] int not null,
	[sysjobhistory_instance_id] int not null,
	[sysjobhistory_step_id] int not null,
	[run_duration_s] real not null,
	[run_date] datetime not null,
	[run_status] tinyint not null,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null,
	[run_date_utc] datetime not null constraint df_sqlwatch_logger_agent_job_history_run_date_utc default ('1970-01-01'),
	constraint fk_sqlwatch_logger_agent_job_history_job foreign key ([sql_instance],[sqlwatch_job_id],[sqlwatch_job_step_id]) 
		references [dbo].[sqlwatch_meta_agent_job_step] (sql_instance, [sqlwatch_job_id], sqlwatch_job_step_id) on delete cascade,
	constraint fk_sqlwatch_logger_agent_job_history_snapshot_header foreign key ([snapshot_time], [sql_instance], [snapshot_type_id]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time], [sql_instance], [snapshot_type_id]) on delete cascade on update cascade
)
go