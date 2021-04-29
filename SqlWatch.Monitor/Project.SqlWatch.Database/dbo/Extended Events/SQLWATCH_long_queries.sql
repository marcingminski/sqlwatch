CREATE EVENT SESSION [SQLWATCH_long_queries]  ON SERVER 

/*  any query that ran for longer than 5 seconds 
    There is no description of what a long query is. This will depend on your application and any SLAs that you may have.
    In OLTP systems, transaction times are often in milliseconds and can be minutes or even hours in Data Warehouses.

    You will have to adjust this time according to your workload. 
    You will also have to keep an eye on the [dbo].[sqlwatch_logger_xes_long_queries] table to make it does not blow too much if you many queries lasting over 5 seconds.

---Remove when targeting SQL2008	*/
ADD EVENT sqlserver.module_end(SET collect_statement=(0)
    ACTION(sqlserver.sql_text, sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.tsql_stack,sqlserver.username)
    WHERE (
            [package0].[greater_than_uint64]([duration],(5000000)) 
        AND [sqlserver].[is_system]=(0)
        /* exclude anything coming from SSMS that isn't a user query. Queries will be Microsoft SQL Server Management Studio - Query */
        AND [sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio'
        /* if intellinse causes blocking, which it may do, we're gonna pick it up in the blocking session 
           otherwise, whilst its a bad practice to run ssms in production, there's not much we can do about intellisense */
        AND [sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio - Transact-SQL IntelliSense'
        /* exclude SQL Server Telemetry Events */
        AND [sqlserver].[client_app_name]<>N'SQLServerCEIP'
        /* internal SQL Agent processes */
        AND [sqlserver].[client_app_name]<>N'SQLAgent - Job Manager'
        AND [sqlserver].[client_app_name]<>N'SQLAgent - Job invocation engine'
        AND [sqlserver].[client_app_name]<>N'SQLAgent - Schedule Saver'

        -- ALSO EXCLUDE ANYTHING RUN AS AN AGENT JOB:
        )),

ADD EVENT sqlserver.rpc_completed(SET collect_statement=(0)
    ACTION(sqlserver.sql_text, sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.tsql_stack,sqlserver.username)
    WHERE (
            [package0].[greater_than_uint64]([duration],(5000000)) 
            /* the query must have done some work to make sure we're not capturing waitfors etc 
               even if  aprocess had had logical or physical reads but 0 CPU, the reads will be minuscule */
            AND [package0].[greater_than_uint64]([cpu_time],(0))
            /* + it must have done either of the below */
            AND (
                    [result]=(2) 
                OR  [package0].[greater_than_uint64]([logical_reads],(0)) 
                OR  [package0].[greater_than_uint64]([physical_reads],(0)) 
                OR  [package0].[greater_than_uint64]([writes],(0))
                ) 
            /* must not be system process */
            AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))
            /* and must not be any of the below */
            AND [sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio'
            AND [sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio - Transact-SQL IntelliSense'
            AND [sqlserver].[client_app_name]<>N'SQLServerCEIP'
            AND [sqlserver].[client_app_name]<>N'SQLAgent - Job Manager'
            AND [sqlserver].[client_app_name]<>N'SQLAgent - Job invocation engine'
            AND [sqlserver].[client_app_name]<>N'SQLAgent - Schedule Saver'
            ),

ADD EVENT sqlserver.sp_statement_completed(SET collect_statement=(0)
    ACTION(sqlserver.sql_text, sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.tsql_stack,sqlserver.username)
    WHERE (
            [package0].[greater_than_int64]([duration],(5000000)) 
            AND [package0].[greater_than_uint64]([cpu_time],(0)) 
            AND (
                    [package0].[greater_than_uint64]([logical_reads],(0)) 
                OR  [package0].[greater_than_uint64]([physical_reads],(0)) 
                OR  [package0].[greater_than_uint64]([writes],(0))
                ) 
            AND [sqlserver].[is_system]=(0))
            AND [sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio'
            AND [sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio - Transact-SQL IntelliSense'
            AND [sqlserver].[client_app_name]<>N'SQLServerCEIP'
            AND [sqlserver].[client_app_name]<>N'SQLAgent - Job Manager'
            AND [sqlserver].[client_app_name]<>N'SQLAgent - Job invocation engine'
            AND [sqlserver].[client_app_name]<>N'SQLAgent - Schedule Saver'
            ),

ADD EVENT sqlserver.sql_statement_completed(SET collect_statement=(0)
    ACTION(sqlserver.sql_text, sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.tsql_stack,sqlserver.username)
    WHERE (
            [package0].[greater_than_int64]([duration],(5000000)) 
            AND [package0].[greater_than_uint64]([cpu_time],(0)) 
            AND (
                    [package0].[greater_than_uint64]([logical_reads],(0)) 
                OR  [package0].[greater_than_uint64]([physical_reads],(0)) 
                OR  [package0].[greater_than_uint64]([writes],(0))
                ) 
            AND [sqlserver].[is_system]=(0))
            AND [sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio'
            AND [sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio - Transact-SQL IntelliSense'
            AND [sqlserver].[client_app_name]<>N'SQLServerCEIP'
            AND [sqlserver].[client_app_name]<>N'SQLAgent - Job Manager'
            AND [sqlserver].[client_app_name]<>N'SQLAgent - Job invocation engine'
            AND [sqlserver].[client_app_name]<>N'SQLAgent - Schedule Saver'
            )

--we could use the plan_handle and get execution plan from sys.dm_exec_query_plan when we load it into a table
--but I found a high percentage of "plan not found" or "incorrect plan handle" errors so I'm collecting execution plan as part of the XES
--this will increase the size of the xel file but will have to do until I find a better approach to get exec plans

--this is too much impact. we're going to have to get plans from plan_handle:
--ADD EVENT sqlserver.query_post_execution_showplan(SET collect_database_name=(1)
--    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.tsql_frame,sqlserver.tsql_stack,sqlserver.username)
--    WHERE ([package0].[greater_than_uint64]([duration],(5000000))))

ADD TARGET package0.event_file(SET filename='SQLWATCH_long_queries.xel', max_file_size=(5), max_rollover_files=(0))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=5 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO