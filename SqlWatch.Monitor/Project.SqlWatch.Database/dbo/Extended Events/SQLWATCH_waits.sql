CREATE EVENT SESSION [SQLWATCH_waits] 
ON SERVER

/*	any query that waited over 1 second for a resource
	Remove when targeting SQL2008	*/

--ADD EVENT sqlos.wait_completed(SET collect_wait_resource=(1)
--    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.query_hash,sqlserver.query_hash_signed,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.username)
--    WHERE ([package0].[greater_than_uint64]([duration],(1000)) AND [sqlserver].[not_equal_i_sql_unicode_string]([sqlserver].[sql_text],N''))),
ADD EVENT sqlserver.sp_statement_completed(SET collect_statement=(1)
    ACTION(sqlserver.query_hash)
    WHERE ([package0].[greater_than_int64]([duration],(1000000)) AND [sqlserver].[query_hash]>(0))),
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.query_hash)
    WHERE ([package0].[greater_than_int64]([duration],(1000000)) AND [sqlserver].[query_hash]>(0)))
ADD TARGET package0.event_file(SET filename=N'SQLWATCH_waits.xel',max_file_size=(2),max_rollover_files=(1))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=1 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO