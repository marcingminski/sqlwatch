CREATE EVENT SESSION [SQLWATCH_health] ON SERVER 
ADD EVENT sqlserver.error_reported(
    ACTION(sqlserver.sql_text)
    WHERE [sqlserver].[like_i_sql_unicode_string]([sqlserver].[sql_text],N'%sqlwatch%') 
	AND (NOT [sqlserver].[like_i_sql_unicode_string]([message],N'%Warning:%'))),

ADD EVENT sqlserver.sp_statement_completed(SET collect_statement=(1)
    ACTION(sqlserver.sql_text)
    WHERE (
        --log any sqlwatch procedure running for longer than 1 second (there will be genuine exceptions)
            [sqlserver].[like_i_sql_unicode_string]([sqlserver].[sql_text],N'%usp_sqlwatch%') 
        AND [package0].[greater_than_int64]([duration],(1000000)) 
        AND (NOT [sqlserver].[like_i_sql_unicode_string]([sqlserver].[sql_text],N'%usp_sqlwatch_logger_whoisactive%')))
    OR (
        -- log performnace logger if it runs for over 500ms - it should take approx 100ms on average.
            [sqlserver].[like_i_sql_unicode_string]([sqlserver].[sql_text],N'%usp_sqlwatch_logger_performance%') 
        AND [package0].[greater_than_int64]([duration],(500000)) ))

ADD TARGET package0.event_file(SET filename=N'SQLWATCH_internal_performance',max_file_size=(50),max_rollover_files=(1))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF);
GO