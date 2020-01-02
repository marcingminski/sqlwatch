CREATE EVENT SESSION [SQLWATCH_waits] 
ON SERVER

/*	any query that waited over 1 second for a resource

	Remove when targeting SQL2008	*/
ADD EVENT sqlos.wait_info(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.tsql_stack,sqlserver.username)
    WHERE ([package0].[greater_than_uint64]([duration],(1000)) AND [package0].[equal_uint64]([opcode],(1)) AND [sqlserver].[sql_text]<>N'')),
ADD EVENT sqlos.wait_info_external(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.tsql_stack,sqlserver.username)
    WHERE ([package0].[greater_than_uint64]([duration],(1000)) AND [package0].[equal_uint64]([opcode],(1)) AND [sqlserver].[sql_text]<>N''))
ADD TARGET package0.ring_buffer(SET max_events_limit=(100))
WITH (MAX_MEMORY=256 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=1 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO