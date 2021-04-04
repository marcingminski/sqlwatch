CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_activated_1m]
AS

-- execute async via broker:
exec [dbo].[usp_sqlwatch_internal_exec_activated_async] @procedure_name = 'dbo.usp_sqlwatch_internal_process_checks';
exec [dbo].[usp_sqlwatch_internal_exec_activated_async] @procedure_name = 'dbo.usp_sqlwatch_logger_hadr_database_replica_states';

-- execute in sequence:
exec dbo.usp_sqlwatch_logger_xes_waits
exec dbo.usp_sqlwatch_logger_xes_blockers
exec dbo.usp_sqlwatch_logger_xes_diagnostics
exec dbo.usp_sqlwatch_logger_xes_long_queries
