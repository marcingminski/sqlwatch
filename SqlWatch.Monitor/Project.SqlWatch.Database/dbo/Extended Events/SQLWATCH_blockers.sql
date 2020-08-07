CREATE EVENT SESSION [SQLWATCH_blockers] ON SERVER 
/*  a custom session to capture blockers as the default health_session is quite busy and would sometimes drop messages
	and generates relatively large xml that can take few seconds to parse. 
	
	Remove when targeting SQL2008	*/
ADD EVENT sqlserver.blocked_process_report(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.tsql_stack,sqlserver.username)),
ADD EVENT sqlserver.xml_deadlock_report
ADD TARGET package0.event_file(SET filename='SQLWATCH_blockers.xel', max_file_size=(1), max_rollover_files=(0))
--ADD TARGET package0.ring_buffer(SET max_events_limit=(100))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO
