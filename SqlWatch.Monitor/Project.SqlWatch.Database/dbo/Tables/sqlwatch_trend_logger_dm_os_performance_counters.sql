CREATE TABLE [dbo].[sqlwatch_trend_logger_dm_os_performance_counters]
(
	[performance_counter_id] int not null,
	[instance_name] nvarchar(128) not null,
	[original_sql_instance] varchar(32) not null,
	[cntr_value_calculated_avg] real null,
	[cntr_value_calculated_min] real null,
	[cntr_value_calculated_max] real null,
	[cntr_value_calculated_sum] real null,
	[original_snapshot_time_from] datetime2(0) not null,
	[original_snapshot_time_to] datetime2(0) not null,
	sample_count int,
	[snapshot_time] datetime2(0) not null,
	snapshot_type_id tinyint,
	sql_instance varchar(32),
	/* aggregates will be detached from header as no new snapshots will be created in the header table when aggregates are created 
	   they will have to be self-maintained when it comes to retention */
	--constraint fk_sqlwatch_aggregate_perf_os_performance_counters_header foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) on delete cascade on update cascade,
	constraint [pk_sqlwatch_trend_perf_os_performance_counters] 
		primary key ([snapshot_time] , [instance_name] , [original_sql_instance], [performance_counter_id], snapshot_type_id, sql_instance  ),
	
	constraint fk_sqlwatch_trend_perf_os_performance_counters_meta 
		foreign key ([original_sql_instance], [performance_counter_id])
		references [dbo].[sqlwatch_meta_dm_os_performance_counters] ([sql_instance], [performance_counter_id]) on delete cascade
)
go