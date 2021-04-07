CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_activated_60m]
AS

--execute async via broker:
exec [dbo].[usp_sqlwatch_internal_exec_activated_async] @procedure_name = 'dbo.usp_sqlwatch_internal_retention';
exec [dbo].[usp_sqlwatch_internal_exec_activated_async] @procedure_name = 'dbo.usp_sqlwatch_internal_purge_deleted_items';

--execute in sequence:
exec dbo.usp_sqlwatch_internal_add_database;
exec dbo.usp_sqlwatch_internal_add_master_file;
exec dbo.usp_sqlwatch_internal_add_table;
exec dbo.usp_sqlwatch_internal_add_job;
exec dbo.usp_sqlwatch_internal_add_performance_counter;
exec dbo.usp_sqlwatch_internal_add_memory_clerk;
exec dbo.usp_sqlwatch_internal_add_wait_type;
exec dbo.usp_sqlwatch_internal_expand_checks;

--exec dbo.usp_sqlwatch_logger_disk_utilisation;

--trends:
exec dbo.usp_sqlwatch_trend_perf_os_performance_counters @interval_minutes = 1, @valid_days = 7
exec dbo.usp_sqlwatch_trend_perf_os_performance_counters @interval_minutes = 5, @valid_days = 90
exec dbo.usp_sqlwatch_trend_perf_os_performance_counters @interval_minutes = 60, @valid_days = 720