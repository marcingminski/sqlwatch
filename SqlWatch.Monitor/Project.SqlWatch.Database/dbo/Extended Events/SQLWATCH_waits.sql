CREATE EVENT SESSION [SQLWATCH_waits] 
ON SERVER

/*	any query that waited over 1 second for a resource
    If a query has to wait over 1 second for a resource you have a big performnace problem.
	Remove when targeting SQL2008	*/

--2014 onwards:
--ADD EVENT sqlos.wait_completed(SET collect_wait_resource=(1)
--    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.query_hash,sqlserver.query_hash_signed,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.username)
--    WHERE ([package0].[greater_than_uint64]([duration],(1000)) AND [sqlserver].[not_equal_i_sql_unicode_string]([sqlserver].[sql_text],N'')))

ADD EVENT sqlos.wait_info(
    ACTION(sqlserver.tsql_frame,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.username)
    WHERE (
            --the filter criteria will be the same for all events in this session:

            --only waits lasting over 1 second 
            [package0].[greater_than_uint64]([duration],(1000)) 

            --only waits that are in a database, this would exclude any background waits that we cannot do anything about
        AND [package0].[greater_than_uint64]([sqlserver].[database_id],(0)) 

            --only include user waits and exclude any system processes
        AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))

        /* exclude anything coming from SSMS that isn't a user query. Queries will be Microsoft SQL Server Management Studio - Query */
        AND [sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio'
        /* if intellinse causes blocking, which it may do, we're gonna pick it up in the blocking session 
           otherwise, whilst its a bad practice to run ssms in production, there's not much we can do about intellisense */
        AND [sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio - Transact-SQL IntelliSense'
        
        /* exclude internal sql agent job management, NOT user jobs. User jobs come across as: 
           SQLAgent - TSQL JobStep (Job 0x123456789123456798 : Step 3) */
        AND [sqlserver].[client_app_name]<>N'SQLAgent - Job Manager'
        AND [sqlserver].[client_app_name]<>N'SQLAgent - Job invocation engine'
        AND [sqlserver].[client_app_name]<>N'SQLAgent - Schedule Saver'
        ),

ADD EVENT sqlos.wait_info_external(
    ACTION(sqlserver.tsql_frame, sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.username)
    WHERE (
            [package0].[greater_than_uint64]([duration],(1000)) 
        AND [package0].[greater_than_uint64]([sqlserver].[database_id],(0)) 
        AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))
        AND [sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio'
        AND [sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio - Transact-SQL IntelliSense'
        AND [sqlserver].[client_app_name]<>N'SQLAgent - Job Manager'
        AND [sqlserver].[client_app_name]<>N'SQLAgent - Job invocation engine'
        AND [sqlserver].[client_app_name]<>N'SQLAgent - Schedule Saver'
        )

ADD TARGET package0.event_file(SET filename=N'SQLWATCH_waits.xel',max_file_size=(2),max_rollover_files=(1))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=1 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO