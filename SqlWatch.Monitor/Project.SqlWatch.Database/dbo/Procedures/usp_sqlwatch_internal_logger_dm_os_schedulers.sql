CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_dm_os_schedulers]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
as
begin

	set nocount on ;

	insert into [dbo].[sqlwatch_logger_dm_os_schedulers] (
		 [scheduler_count]
		,[idle_scheduler_count] 
		,[current_tasks_count]
		,[runnable_tasks_count]
		,[preemptive_switches_count]
		,[context_switches_count]
		,[idle_switches_count]
		,[current_workers_count]
		,[active_workers_count]
		,[work_queue_count]
		,[pending_disk_io_count]
		,[load_factor]
		,[yield_count]
		,[failed_to_create_worker]
		,[total_cpu_usage_ms]
		,[total_scheduler_delay_ms]		 

		,[snapshot_time] 
		,[snapshot_type_id] 
		,[sql_instance] 
	)
	select
		 [scheduler_count]
		,[idle_scheduler_count] 
		,[current_tasks_count]
		,[runnable_tasks_count]
		,[preemptive_switches_count]
		,[context_switches_count]
		,[idle_switches_count]
		,[current_workers_count]
		,[active_workers_count]
		,[work_queue_count]
		,[pending_disk_io_count]
		,[load_factor]
		,[yield_count]
		,[failed_to_create_worker]
		,[total_cpu_usage_ms]
		,[total_scheduler_delay_ms]		
		,snapshot_time = @snapshot_time
		,snapshot_type_id = @snapshot_type_id
		,sql_instance = @sql_instance
	from openxml (@xdoc, '/CollectionSnapshot/dm_os_schedulers/row',1) 
		with (
			 scheduler_count smallint
			 ,idle_scheduler_count smallint
			 ,current_tasks_count int
			 ,runnable_tasks_count int
			 ,preemptive_switches_count bigint
			 ,context_switches_count bigint
			 ,idle_switches_count bigint
			 ,current_workers_count int
			 ,active_workers_count int
			 ,work_queue_count int
			 ,pending_disk_io_count  int
			 ,load_factor int
			 ,yield_count bigint
			 ,failed_to_create_worker  int
			 ,total_cpu_usage_ms bigint
			 ,total_scheduler_delay_ms bigint 
		)
	option (maxdop 1, keep plan);
end;