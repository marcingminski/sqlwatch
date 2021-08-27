CREATE TABLE [dbo].[sqlwatch_meta_dm_os_performance_counters_instance]
(
	performance_counter_instance_id int not null identity(1,1),
	performance_counter_id int not null,
	instance_name nvarchar(128),
	[sql_instance] varchar(32),
	[date_updated] datetime,

	constraint pk_sqlwatch_stage_performance_counters_to_collect 
	primary key clustered (performance_counter_instance_id, performance_counter_id, [sql_instance]),

	constraint fk_sqlwatch_stage_performance_counters_to_collect_perf_id
	foreign key ([sql_instance], [performance_counter_id])
	references [dbo].[sqlwatch_meta_dm_os_performance_counters] ([sql_instance], [performance_counter_id])
	on delete cascade
)
