CREATE TABLE [dbo].[sqlwatch_trend_perf_os_performance_counters]
(
	[performance_counter_id] smallint not null,
	[instance_name] nvarchar(128) not null,
	[sql_instance] varchar(32) not null,
	[cntr_value_calculated_avg] real null,
	[cntr_value_calculated_min] real null,
	[cntr_value_calculated_max] real null,
	[cntr_value_calculated_sum] real null,
	[interval_minutes] tinyint not null,
	[snapshot_time] datetime2(0) not null,

	/* this cannot be PK on its own as these are the same and would cause violation:
		2021-03-28 01:00:00 +00:00
		2021-03-28 02:00:00 +01:00
	*/
	[snapshot_time_offset] datetimeoffset(0), 
	[valid_until] datetime2(0) ,
	/* aggregates will be detached from header as no new snapshots will be created in the header table when aggregates are created 
	   they will have to be self-maintained when it comes to retention */
	--constraint fk_sqlwatch_aggregate_perf_os_performance_counters_header foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) on delete cascade on update cascade,
	constraint [pk_sqlwatch_trend_perf_os_performance_counters] 
		primary key ([snapshot_time] , [instance_name] , [sql_instance], [interval_minutes], [performance_counter_id]  ),
	constraint fk_sqlwatch_trend_perf_os_performance_counters_meta 
		foreign key ([sql_instance], [performance_counter_id])
		references [dbo].[sqlwatch_meta_performance_counter] ([sql_instance], [performance_counter_id]) on delete cascade
)
go

CREATE NONCLUSTERED INDEX sqlwatch_trend_perf_os_performance_counters_value
ON [dbo].[sqlwatch_trend_perf_os_performance_counters] ([performance_counter_id],[sql_instance],[interval_minutes])
INCLUDE ([cntr_value_calculated_avg])
go

CREATE NONCLUSTERED INDEX idx_sqlwatch_trend_perf_os_performance_counters_valid_until
ON dbo.sqlwatch_trend_perf_os_performance_counters ([valid_until])

go
