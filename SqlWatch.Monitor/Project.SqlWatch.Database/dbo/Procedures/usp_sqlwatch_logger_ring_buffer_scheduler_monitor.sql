CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_ring_buffer_scheduler_monitor]
as

declare @percent_idle_time real, @percent_processor_time real;

truncate table [dbo].[sqlwatch_stage_ring_buffer];

insert into [dbo].[sqlwatch_stage_ring_buffer] (snapshot_time, percent_processor_time, percent_idle_time, memory_utilization)
		SELECT 
			snapshot_time=getutcdate(),
			percent_processor_time=record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int'),
			percent_idle_time=record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int'), 
			memory_utilization=record.value('(./Record/SchedulerMonitorEvent/SystemHealth/MemoryUtilization)[1]', 'int')
		FROM ( 
			SELECT TOP 1 CONVERT(xml, record) AS [record] 
			FROM sys.dm_os_ring_buffers WITH (NOLOCK)
			WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' collate database_default
			AND record LIKE N'%<SystemHealth>%' collate database_default
			ORDER BY [timestamp] DESC
			) AS x 
OPTION (keep plan);