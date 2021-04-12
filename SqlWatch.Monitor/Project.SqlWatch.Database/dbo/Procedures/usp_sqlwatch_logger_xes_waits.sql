CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_xes_waits]
AS

--this needs to be reviewed. I am not happy with how we're getting the query hash
--we also need to add conditional execution like in the other collectors based on the xes exec count
if [dbo].[ufn_sqlwatch_get_product_version]('major') >= 11
	begin

		set nocount on

		select event_data_xml=convert(xml,event_data), object_name
		into #event_data
		from sys.fn_xe_file_target_read_file ('SQLWATCH_waits*.xel', null, null, null) t

		-- get only new events. This results in much smaller xml to parse in the steps below and dramatically speeds up the query
		where substring(event_data,PATINDEX('%timestamp%',event_data)+len('timestamp="'),24) >=
		isnull((select max(event_time) from [dbo].[sqlwatch_logger_xes_wait_event]),'1970-01-01')

		;with cte_waits as (
			select
				[event_time] = xed.event_data.value('(@timestamp)[1]', 'datetime'),
				[wait_type] = xed.event_data.value('(data[@name="wait_type"]/text)[1]', 'varchar(255)'),
				[duration] = xed.event_data.value('(data[@name="duration"]/value)[1]', 'bigint'),
				[signal_duration] = xed.event_data.value('(data[@name="signal_duration"]/value)[1]', 'bigint'),
				[activity_id_t] = xed.event_data.value('(action[@name="attach_activity_id"]/value)[1]', 'varchar(255)'),
				[query_hash] = xed.event_data.value('(action[@name="query_hash"]/value)[1]', 'decimal(20,0)'),
				[session_id] = xed.event_data.value('(action[@name="session_id"]/value)[1]', 'int'),
				[username] = xed.event_data.value('(action[@name="username"]/value)[1]', 'varchar(255)'),
				[sql_text] = xed.event_data.value('(action[@name="sql_text"]/value)[1]', 'varchar(max)'),
				[database_name] = xed.event_data.value('(action[@name="database_name"]/value)[1]', 'varchar(255)'),
				[client_hostname] = xed.event_data.value('(action[@name="client_hostname"]/value)[1]', 'varchar(255)'),
				[client_app_name] = xed.event_data.value('(action[@name="client_app_name"]/value)[1]', 'varchar(255)'),

				-- We are using the original query_hash if provided and if not, calculate our own from the text data.
				-- If the query hash is provided, we convert it to varbinary so they all fit into a single column to create PK
				-- MD5 is enough for what we need. its 128 bits, 16 bytes long, next one up is 20 bytes so considerably larger.
				[sqlwatch_query_hash] = case when xed.event_data.value('(action[@name="query_hash"]/value)[1]', 'decimal(20,0)') > 0 then 
					convert(varbinary(16),xed.event_data.value('(action[@name="query_hash"]/value)[1]', 'decimal(20,0)'))
					else hashbytes('MD5',xed.event_data.value('(action[@name="sql_text"]/value)[1]', 'varchar(max)')) end
			from #event_data t
			cross apply t.event_data_xml.nodes('event') as xed (event_data)
			where t.object_name in ('wait_completed')

			-- exclude any waits we dont want to collect:
			and xed.event_data.value('(data[@name="wait_type"]/text)[1]', 'varchar(255)') not in (
				select wait_type from sqlwatch_config_exclude_wait_stats
			)
		)
		select *
			-- calculate an actualy activity_id and the sequence. They are both concatenated in the XES:
			, [activity_id]=substring([activity_id_t],1,len([activity_id_t])-charindex('-',reverse([activity_id_t])))
			, [activity_id_sequence] = right([activity_id_t],charindex('-',reverse([activity_id_t]))-1)		
		into #w
		from cte_waits
		option (maxdop 1)

		;with cte_queries as (
			select
				[event_time] = xed.event_data.value('(@timestamp)[1]', 'datetime'),
				[event_name]=xed.event_data.value('(@name)[1]', 'varchar(255)'),
				[activity_id_t] = xed.event_data.value('(action[@name="attach_activity_id"]/value)[1]', 'varchar(255)'),
				[query_hash] = xed.event_data.value('(action[@name="query_hash"]/value)[1]', 'decimal(20,0)'),
				[statement] = xed.event_data.value('(data[@name="statement"]/value)[1]', 'varchar(max)'),		

				-- Becuase we are filtering the XES to only return queries with the hash, we can convert it to binary straight away:
				[sqlwatch_query_hash] = convert(varbinary(16),xed.event_data.value('(action[@name="query_hash"]/value)[1]', 'decimal(20,0)'))
			from #event_data t
			cross apply t.event_data_xml.nodes('event') as xed (event_data)
			where t.object_name in ('sp_statement_completed','sql_statement_completed')
			-- the XE session has a filter to only returns queries with hash so this is not required
			-- and xed.event_data.value('(action[@name="query_hash"]/value)[1]', 'decimal(20,0)') > 0
		)
		select *
			-- calculate an actualy activity_id and the sequence. They are both concatenated in the XES:
			, [activity_id]=substring([activity_id_t],1,len([activity_id_t])-charindex('-',reverse([activity_id_t])))
			, [activity_id_sequence] = right([activity_id_t],charindex('-',reverse([activity_id_t]))-1)
		into #q
		from cte_queries
		option (maxdop 1)

		/*	the [activity_id] column provides a way of linking events. Whilst we could join the results of  sp_statement_completed and wait_info, 
			there is no real benefit to do so this way round becuase we are capturing the waits first, and then the corresponding query based on the 
			query hash when available. If no query hash available we are using the sql_text provided by the waitinfo. 
			
			the *_statement completed captures lots of statements that ran as part of the same query that may have not had a wait.
			If we wanted to capture waits stats for a particular query or procedure, we would have done it the other way around:
			Capture the queries and the waits assosiated with that particular execution and join on the activity_id */

		set xact_abort on
		begin transaction

			-- insert any new queries into the "query repository" table.
			-- this will also include queries with hash calcualted from the text rather than the actual query_hash.
			-- this means that some queries may be repeated if part of the statement is different. However, we would have captured
			-- these anyway as part of the [dbo].[sqlwatch_logger_xes_wait_event]

			-- we will try to get the sql statement based on the actual query_hash from sql server.
			-- if the query_hash is not available, we will calcualte our own from the sql_text (statement and sql_text are different things)	
			;merge [dbo].[sqlwatch_meta_sql_query] as target
			using (
				select t.[sqlwatch_query_hash],  sql_text= isnull(s.statement, x.sql_text)
				from (
					select distinct [sqlwatch_query_hash]
					from #q
					union
					select distinct [sqlwatch_query_hash]
					from #w
				) t
				outer apply (
					select top 1 statement
					from #q
					where [sqlwatch_query_hash] = t.[sqlwatch_query_hash]
				) s
				outer apply (
					select top 1 sql_text
					from #w
					where [sqlwatch_query_hash] = t.[sqlwatch_query_hash]
					and s.statement is null
				) x
			) as source
			on target.[sqlwatch_query_hash] = source.[sqlwatch_query_hash]
			and target.sql_instance = @@SERVERNAME

			when matched and datediff(hour,date_last_seen,getutcdate()) > 24 then
				update set date_last_seen = getutcdate()

			when not matched then
				insert (sql_instance, sqlwatch_query_hash, sql_text, date_first_seen, date_last_seen)
				values (@@SERVERNAME, source.sqlwatch_query_hash, source.sql_text, getutcdate(), getutcdate());


			declare @event_data table (event_data xml)
			declare @snapshot_time datetime2(0),
					@snapshot_type_id tinyint = 6

			exec [dbo].[usp_sqlwatch_internal_insert_header] 
				@snapshot_time_new = @snapshot_time OUTPUT,
				@snapshot_type_id = @snapshot_type_id

			insert into [dbo].[sqlwatch_logger_xes_wait_event] (
				  event_time
				, wait_type_id
				, duration
				, signal_duration
				, session_id
				, activity_id
				, activity_id_sequence
				, username
				, sqlwatch_database_id
				, client_hostname
				, client_app_name
				, sqlwatch_query_hash
				, sql_instance
				, snapshot_time
				, snapshot_type_id
				)
			select 
				  w.event_time
				, s.wait_type_id
				, w.duration
				, w.signal_duration
				, w.session_id
				, w.activity_id
				, w.activity_id_sequence
				, w.username
				, db.sqlwatch_database_id
				, w.client_hostname
				, client_app_name = case when w.client_app_name like 'SQLAGent - TSQL JobStep%' then replace(w.client_app_name collate DATABASE_DEFAULT,left(replace(w.client_app_name collate DATABASE_DEFAULT,'SQLAgent - TSQL JobStep (Job ',''),34),j.name) else w.client_app_name end
				, w.sqlwatch_query_hash
				, @@SERVERNAME
				, @snapshot_time
				, @snapshot_type_id
			from #w w
			inner join dbo.sqlwatch_meta_wait_stats s
				on s.wait_type = w.wait_type
				and s.sql_instance = @@SERVERNAME
			inner join dbo.sqlwatch_meta_database db
				on db.database_name = w.database_name
				and db.is_current = 1
				and db.sql_instance = @@SERVERNAME
			left join msdb.dbo.sysjobs j
				on j.job_id = convert(uniqueidentifier,case when client_app_name like 'SQLAGent - TSQL JobStep%' then convert(varbinary,left(replace(client_app_name collate DATABASE_DEFAULT,'SQLAgent - TSQL JobStep (Job ',''),34),1) else null end)
			left join [dbo].[sqlwatch_logger_xes_wait_event] t
				on t.event_time = w.event_time
				and t.activity_id = w.activity_id
				and t.activity_id_sequence = w.activity_id_sequence
				and t.sql_instance = @@SERVERNAME
			where t.activity_id is null

	commit transaction 

	end
else
	print 'Product version must be 11 or higher'

