CREATE EVENT SESSION [SQLWATCH_long_queries]  ON SERVER 

/* any query that ran for longer than 15 seconds 

Remove when targeting SQL2008	*/
ADD EVENT sqlserver.module_end(SET collect_statement=(1)
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.tsql_stack,sqlserver.username)
    WHERE ([package0].[greater_than_uint64]([duration],(15000000)) AND [sqlserver].[is_system]=(0))),
ADD EVENT sqlserver.rpc_completed(SET collect_statement=(1)
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.tsql_stack,sqlserver.username)
    WHERE ([package0].[greater_than_uint64]([duration],(15000000)) AND ([result]=(2) OR [package0].[greater_than_uint64]([logical_reads],(0)) OR [package0].[greater_than_uint64]([cpu_time],(0)) OR [package0].[greater_than_uint64]([physical_reads],(0)) OR [package0].[greater_than_uint64]([writes],(0))) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))),
ADD EVENT sqlserver.sp_statement_completed(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.tsql_stack,sqlserver.username)
    WHERE ([package0].[greater_than_int64]([duration],(15000000)) AND ([package0].[greater_than_uint64]([cpu_time],(0)) OR [package0].[greater_than_uint64]([logical_reads],(0)) OR [package0].[greater_than_uint64]([physical_reads],(0)) OR [package0].[greater_than_uint64]([writes],(0))) AND [sqlserver].[is_system]=(0))),
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.tsql_stack,sqlserver.username)
    WHERE ([package0].[greater_than_int64]([duration],(15000000)) AND ([package0].[greater_than_uint64]([cpu_time],(0)) OR [package0].[greater_than_uint64]([logical_reads],(0)) OR [package0].[greater_than_uint64]([physical_reads],(0)) OR [package0].[greater_than_uint64]([writes],(0))) AND [sqlserver].[is_system]=(0)))
--ADD TARGET package0.ring_buffer(SET max_events_limit=(250))
ADD TARGET package0.event_file(SET filename='SQLWATCH_long_queries.xel', max_file_size=(5), max_rollover_files=(0))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO