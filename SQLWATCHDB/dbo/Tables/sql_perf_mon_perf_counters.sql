CREATE TABLE [dbo].[sql_perf_mon_perf_counters]
(
	[object_name] nvarchar(4000) not null,
	[instance_name] nvarchar(4000) not null,
	[counter_name] nvarchar(4000) not null,
	[cntr_value] bigint not null,
	[base_cntr_value] bigint null,
	[cntr_type] bigint not null,
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint not null default 1 ,
	constraint fk_sql_perf_mon_perf_counters_snapshot_header foreign key ([snapshot_time],[snapshot_type_id]) references [dbo].[sql_perf_mon_snapshot_header]([snapshot_time],[snapshot_type_id]) on delete cascade ,
	constraint [pk_sql_perf_mon_perf_counters] primary key ([snapshot_time] asc, [object_name] asc, [counter_name] asc, [instance_name] asc)
)
