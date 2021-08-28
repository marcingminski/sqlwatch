CREATE TABLE [dbo].[sqlwatch_logger_dm_exec_sessions_stats]
(
	[type] bit not null, --1-user; 0-system
	snapshot_time datetime2(0) not null,
	snapshot_type_id tinyint not null,
	sql_instance varchar(32) not null,
	running real not null,
	sleeping real not null,
	dormant real not null,
	preconnect real not null,
	cpu_time real not null,
	reads real not null,
	writes real not null,
	memory_usage real,

	constraint pk_sqlwatch_logger_dm_exec_sessions  primary key clustered
	(
		[type] ASC,
		[snapshot_time] ASC,
		[snapshot_type_id] ASC,
		[sql_instance] ASC
	),

	constraint [fk_sqlwatch_logger_dm_exec_sessions_snapshot_header] 
	foreign key ([snapshot_time], [sql_instance], [snapshot_type_id])
	references [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_time], [sql_instance], [snapshot_type_id])
	on delete cascade
);
