CREATE PROCEDURE [dbo].[usp_sqlwatch_local_meta_add]
as
begin

    declare @cid uniqueidentifier;

    exec [dbo].[usp_sqlwatch_internal_broker_dialog_new]
        @cid = @cid output;

    exec [dbo].[usp_sqlwatch_local_logger_enqueue_metadata_snapshot] @metadata = 'meta_server', @cid = @cid;
    exec [dbo].[usp_sqlwatch_local_logger_enqueue_metadata_snapshot] @metadata = 'sys_databases', @cid = @cid;
    exec [dbo].[usp_sqlwatch_local_logger_enqueue_metadata_snapshot] @metadata = 'sys_master_files', @cid = @cid;
    exec [dbo].[usp_sqlwatch_local_logger_enqueue_metadata_snapshot] @metadata = 'sys_jobs', @cid = @cid;

                                        
    exec [dbo].[usp_sqlwatch_local_logger_enqueue_metadata_snapshot] @metadata = 'dm_os_memory_clerks', @cid = @cid;
    exec [dbo].[usp_sqlwatch_local_logger_enqueue_metadata_snapshot] @metadata = 'dm_os_wait_stats', @cid = @cid;
    exec [dbo].[usp_sqlwatch_local_logger_enqueue_metadata_snapshot] @metadata = 'dm_os_performance_counters', @cid = @cid;

    exec [dbo].[usp_sqlwatch_internal_broker_dialog_end]
        @cid = @cid;

end;

