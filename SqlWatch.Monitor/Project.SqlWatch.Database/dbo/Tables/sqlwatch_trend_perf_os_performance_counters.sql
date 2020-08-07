CREATE TABLE [dbo].[sqlwatch_trend_perf_os_performance_counters]
(
	[performance_counter_id] smallint not null,
	[instance_name] nvarchar(128) not null,
	[report_time] datetime2(0) not null,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_trend_perf_os_performance_counters_sql_instance default (@@SERVERNAME),
	[cntr_value_calculated_avg] real null,
	[cntr_value_calculated_min] real null,
	[cntr_value_calculated_max] real null,
	[trend_interval_minutes] tinyint not null,
	[snapshot_time_offset] datetimeoffset,
	/* aggregates will be detached from header as no new snapshots will be created in the header table when aggregates are created 
	   they will have to be self-maintained when it comes to retention */
	--constraint fk_sqlwatch_aggregate_perf_os_performance_counters_header foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) on delete cascade on update cascade,
	constraint [pk_sqlwatch_trend_perf_os_performance_counters] primary key ([report_time] asc, [trend_interval_minutes],[sql_instance], [performance_counter_id] asc, [instance_name] asc),
	constraint fk_sqlwatch_trend_perf_os_performance_counters_meta foreign key ([sql_instance], [performance_counter_id])
		references [dbo].[sqlwatch_meta_performance_counter] ([sql_instance], [performance_counter_id]) on delete cascade,
	constraint chk_sqlwatch_trend_perf_os_performance_counters_internval check ([trend_interval_minutes] = 60)
)
go

CREATE NONCLUSTERED INDEX sqlwatch_trend_perf_os_performance_counters_value
ON [dbo].[sqlwatch_trend_perf_os_performance_counters] ([performance_counter_id],[sql_instance],[trend_interval_minutes])
INCLUDE ([cntr_value_calculated_avg])

go
