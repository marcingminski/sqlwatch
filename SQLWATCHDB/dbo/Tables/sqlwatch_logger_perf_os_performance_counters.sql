CREATE TABLE [dbo].[sqlwatch_logger_perf_os_performance_counters]
(
	[object_name] nvarchar(4000) not null,
	[instance_name] nvarchar(4000) not null,
	[counter_name] nvarchar(4000) not null,
	[cntr_value] bigint not null,
	[base_cntr_value] bigint null,
	[cntr_type] bigint not null,
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint not null default 1 ,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,
	constraint fk_sql_perf_mon_perf_counters_snapshot_header foreign key ([snapshot_time],[snapshot_type_id],[sql_instance]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id],[sql_instance]) on delete cascade ,
	constraint [pk_sql_perf_mon_perf_counters] primary key ([snapshot_time] asc, [object_name] asc, [counter_name] asc, [instance_name] asc)
)
