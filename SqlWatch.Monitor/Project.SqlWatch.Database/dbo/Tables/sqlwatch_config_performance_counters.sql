CREATE TABLE [dbo].[sqlwatch_config_performance_counters]
(
			[object_name] nvarchar(128) not null,
			[instance_name] nvarchar(128) not null,
			[counter_name] nvarchar(128) not null,
			[base_counter_name] nvarchar(128) null,
			[collect] bit null,
			constraint pk_sql_perf_mon_config_perf_counters primary key (
				[object_name] , [instance_name], [counter_name]
			)
)

go
	create nonclustered index idx_sql_perf_mon_perf_counters_types on dbo.[sqlwatch_config_performance_counters] ([collect]) include ([object_name],[instance_name],[counter_name],[base_counter_name])

