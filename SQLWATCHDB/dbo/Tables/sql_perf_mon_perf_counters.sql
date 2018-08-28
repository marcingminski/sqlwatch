CREATE TABLE [dbo].[sql_perf_mon_perf_counters]
(
	[object_name] varchar(4000) not null,
	[instance_name] varchar(4000) not null,
	[counter_name] varchar(4000) not null,
	[cntr_value] bigint not null,
	[base_cntr_value] bigint null,
	[cntr_type] bigint not null,
	[snapshot_time] datetime foreign key references [dbo].[sql_perf_mon_snapshot_header]([snapshot_time]) on delete cascade not null,
	constraint [pk_sql_perf_mon_perf_counters] primary key ([snapshot_time] asc, [object_name] asc, [counter_name] asc, [instance_name] asc)
)
