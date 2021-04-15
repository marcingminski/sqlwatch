CREATE EVENT SESSION [SQLWATCH_query_problems]
	ON SERVER

ADD EVENT sqlserver.sp_cache_miss(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.sql_text,sqlserver.username)
    WHERE ([sqlserver].[is_system]=(0)) 

    /*  We're excluding queries coming from "Microsoft SQL Server Management Studio". These are the queries that SSMS is sending to SQL Server when you
        brower databases, events, anything really. 
        When you are running a query in SSMS, the Application Name is then: "Microsoft SQL Server Management Studio - Query"
        I would not surprised if this behaviour was different across different versions of SSMS. Tested with SQL Server Management Studio 15.0.18333.0
        You may want to run some tests in your environment to see if this is true for you */
        and ([sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio')

        -- exclude SQL Server Telemetry Events
        and ([sqlserver].[client_app_name]<>N'SQLServerCEIP')

        -- exclude Dacpac Deployments --- not much we can about these anyway
        and ([sqlserver].[client_app_name]<>N'DacFx Deploy')    
    ) ,
ADD EVENT sqlserver.additional_memory_grant(
    ACTION(sqlserver.database_name,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.sql_text,sqlserver.username)
    WHERE ([sqlserver].[is_system]=(0)) 
        and ([sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio')
        and ([sqlserver].[client_app_name]<>N'SQLServerCEIP')
        and ([sqlserver].[client_app_name]<>N'DacFx Deploy')    
    ) ,
ADD EVENT sqlserver.exchange_spill(
    ACTION(sqlserver.database_name,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.sql_text,sqlserver.username)
    WHERE ([sqlserver].[is_system]=(0)) 
        and ([sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio')
        and ([sqlserver].[client_app_name]<>N'SQLServerCEIP')
        and ([sqlserver].[client_app_name]<>N'DacFx Deploy')    
    ) ,
ADD EVENT sqlserver.execution_warning(
    ACTION(sqlserver.database_name,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.sql_text,sqlserver.username)
    WHERE ([sqlserver].[is_system]=(0)) 
        and ([sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio')
        and ([sqlserver].[client_app_name]<>N'SQLServerCEIP')
        and ([sqlserver].[client_app_name]<>N'DacFx Deploy')    
    ) ,
ADD EVENT sqlserver.hash_spill_details(
    ACTION(sqlserver.database_name,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.sql_text,sqlserver.username)
    WHERE ([sqlserver].[is_system]=(0)) 
        and ([sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio')
        and ([sqlserver].[client_app_name]<>N'SQLServerCEIP')
        and ([sqlserver].[client_app_name]<>N'DacFx Deploy')    
    ) ,
ADD EVENT sqlserver.hash_warning(
    ACTION(sqlserver.database_name,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.sql_text,sqlserver.username)
    WHERE ([sqlserver].[is_system]=(0)) 
        and ([sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio')
        and ([sqlserver].[client_app_name]<>N'SQLServerCEIP')
        and ([sqlserver].[client_app_name]<>N'DacFx Deploy')    
    ) ,
ADD EVENT sqlserver.long_io_detected(
    ACTION(sqlserver.database_name,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.sql_text,sqlserver.username)
    WHERE ([sqlserver].[is_system]=(0)) 
        and ([sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio')
        and ([sqlserver].[client_app_name]<>N'SQLServerCEIP')
        and ([sqlserver].[client_app_name]<>N'DacFx Deploy')    
    ) ,

ADD EVENT sqlserver.missing_column_statistics(
    SET collect_column_list=(1)
    ACTION(sqlserver.database_name,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.sql_text,sqlserver.username)
    WHERE ([sqlserver].[is_system]=(0) 
        and [sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio' 
        and [sqlserver].[client_app_name]<>N'SQLServerCEIP' 
        and [sqlserver].[client_app_name]<>N'DacFx Deploy')
    ) ,

ADD EVENT sqlserver.missing_join_predicate(
    ACTION(sqlserver.database_name,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.sql_text,sqlserver.username)
      WHERE ([sqlserver].[is_system]=(0)) 
        and ([sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio')
        and ([sqlserver].[client_app_name]<>N'SQLServerCEIP')
        and ([sqlserver].[client_app_name]<>N'DacFx Deploy')    
    ) ,
ADD EVENT sqlserver.optimizer_timeout(
    ACTION(sqlserver.database_name,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.sql_text,sqlserver.username)
      WHERE ([sqlserver].[is_system]=(0)) 
        and ([sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio')
        and ([sqlserver].[client_app_name]<>N'SQLServerCEIP')
        and ([sqlserver].[client_app_name]<>N'DacFx Deploy')    
    ) ,
ADD EVENT sqlserver.plan_affecting_convert(
    ACTION(sqlserver.database_name,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.sql_text,sqlserver.username)
     WHERE ([sqlserver].[is_system]=(0)) 
        and ([sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio')
        and ([sqlserver].[client_app_name]<>N'SQLServerCEIP')
        and ([sqlserver].[client_app_name]<>N'DacFx Deploy')    
    ) ,
ADD EVENT sqlserver.sort_warning(
    ACTION(sqlserver.database_name,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.sql_text,sqlserver.username)
    WHERE ([sqlserver].[is_system]=(0)) 
        and ([sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio')
        and ([sqlserver].[client_app_name]<>N'SQLServerCEIP')
        and ([sqlserver].[client_app_name]<>N'DacFx Deploy')    
    ) ,
ADD EVENT sqlserver.unmatched_filtered_indexes(
    ACTION(sqlserver.database_name,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.sql_text,sqlserver.username)
    WHERE ([sqlserver].[is_system]=(0)) 
        and ([sqlserver].[client_app_name]<>N'Microsoft SQL Server Management Studio')
        and ([sqlserver].[client_app_name]<>N'SQLServerCEIP')
        and ([sqlserver].[client_app_name]<>N'DacFx Deploy')    
    ) 

ADD TARGET package0.event_file(SET filename=N'SQLWATCH_query_problems.xel',max_file_size=(5),max_rollover_files=(0))
WITH (
	 MAX_MEMORY=4096 KB
	,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS
	,MAX_DISPATCH_LATENCY=30 SECONDS
	,MAX_EVENT_SIZE=0 KB
	,MEMORY_PARTITION_MODE=NONE
	,TRACK_CAUSALITY=OFF
	,STARTUP_STATE=ON
	)
GO