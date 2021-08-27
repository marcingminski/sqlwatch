CREATE TABLE [dbo].[sqlwatch_stage_ring_buffer]
(
	snapshot_time datetime2(0),
	percent_processor_time int,
	percent_idle_time int,
	memory_utilization int,

	constraint pk_sqlwatch_stage_logger_ring_buffer primary key clustered (snapshot_time)
)