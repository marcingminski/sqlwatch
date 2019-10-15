CREATE TABLE [dbo].[sqlwatch_logger_perf_os_performance_counters]
(
	[performance_counter_id] smallint not null,
	[instance_name] nvarchar(128) not null,
	--[counter_name] nvarchar(128) not null,
	[cntr_value] bigint not null,
	[base_cntr_value] bigint null,
	--[cntr_type] bigint not null,
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint not null default 1 ,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,
	constraint fk_sql_perf_mon_perf_counters_snapshot_header foreign key ([snapshot_time],[snapshot_type_id],[sql_instance]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id],[sql_instance]) on delete cascade on update cascade,
	constraint [pk_sql_perf_mon_perf_counters] primary key ([snapshot_time] asc, [snapshot_type_id],[sql_instance], [performance_counter_id] asc, [instance_name] asc)
)
go

/* aid filtering by server in central repository */
--CREATE NONCLUSTERED INDEX idx_sqlwatch_perf_counters_001
--ON [dbo].[sqlwatch_logger_perf_os_performance_counters] ([sql_instance])
--INCLUDE ([performance_counter_id],[instance_name],[cntr_value],[base_cntr_value],[snapshot_time],[snapshot_type_id])

--GO
--CREATE NONCLUSTERED INDEX idx_sqlwatch_perf_counters_002
--ON [dbo].[sqlwatch_logger_perf_os_performance_counters] ([snapshot_type_id],[sql_instance],[snapshot_time])
--INCLUDE ([performance_counter_id],[instance_name],[cntr_value],[base_cntr_value])

--CREATE NONCLUSTERED INDEX idx_sqlwatch_perf_counters_003
--ON [dbo].[sqlwatch_logger_perf_os_performance_counters] ([performance_counter_id],[sql_instance])
--INCLUDE ([cntr_value],[base_cntr_value])
