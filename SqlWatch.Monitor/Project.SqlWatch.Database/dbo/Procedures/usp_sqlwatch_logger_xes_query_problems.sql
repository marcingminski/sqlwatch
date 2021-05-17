CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_xes_query_problems]
as


set nocount on

/*

THIS IS NOT YET READY AS THE XES NEEDS MORE WORK

declare @snapshot_time datetime2(0),
		@snapshot_type_id tinyint = 6

declare @execution_count bigint = 0,
		@session_name nvarchar(64) = 'SQLWATCH_query_problems',
		@address varbinary(8),
		@filename varchar(8000),
		@sql_instance varchar(32) = dbo.ufn_sqlwatch_get_servername(),
		@store_event_data smallint = dbo.ufn_sqlwatch_get_config_value(23,null),
		@last_event_time datetime;;

declare @event_data utype_event_data;

--quit if the collector is switched off
if (select collect 
	from [dbo].[sqlwatch_config_snapshot_type]
	where snapshot_type_id = @snapshot_type_id
	) = 0
	begin
		return;
	end;

exec [dbo].[usp_sqlwatch_internal_insert_header] 
	@snapshot_time_new = @snapshot_time OUTPUT,
	@snapshot_type_id = @snapshot_type_id;

begin tran;

	insert into @event_data
	exec [dbo].[usp_sqlwatch_internal_get_xes_data]
		@session_name = @session_name;

	--bail out of no xes data to process:
	if not exists (select top 1 * from @event_data)
		begin
			commit tran;
			return;
		end;


--quit of the collector is switched off
if (select collect from [dbo].[sqlwatch_config_snapshot_type]
	where snapshot_type_id = @snapshot_type_id) = 0
		begin
			return
		end;

SELECT 
	 [event_time]=xed.event_data.value('(@timestamp)[1]', 'datetime')
	,[event_name]=xed.event_data.value('(@name)[1]', 'varchar(255)')
	,[username]=xed.event_data.value('(action[@name="username"]/value)[1]', 'varchar(255)')
	--,[sql_text]=xed.event_data.value('(action[@name="sql_text"]/value)[1]', 'varchar(max)')
	,[client_hostname]=xed.event_data.value('(action[@name="client_hostname"]/value)[1]', 'varchar(255)')
	,[client_app_name]=xed.event_data.value('(action[@name="client_app_name"]/value)[1]', 'varchar(255)')
	,[problem_details] = t.event_data
	,[event_hashbytes]
	,occurence
into #t_queries
from @event_data t
	cross apply t.event_data.nodes('event') as xed (event_data)
	where xed.event_data.value('(@name)[1]', 'varchar(255)') <> 'query_post_execution_showplan';
	
insert into dbo.[sqlwatch_logger_xes_query_problems] (
		[event_time], event_name, username
	, client_hostname, client_app_name
	, snapshot_time, snapshot_type_id, sql_instance, [problem_details], [event_hash], occurence)

select 
		tx.[event_time], tx.event_name, tx.username
	, tx.client_hostname, tx.client_app_name
	,[snapshot_time] = @snapshot_time
	,[snapshot_type_id] = @snapshot_type_id
	,sql_instance = @sql_instance
	,tx.[problem_details]
	,tx.[event_hashbytes]
	,occurence = o.occurence
from #t_queries tx

-- do not load queries that we arleady have
left join dbo.[sqlwatch_logger_xes_query_problems] x
	on x.[event_hash] = tx.[event_hashbytes]
	and x.event_time = tx.event_time
	and x.event_name = tx.event_name

outer apply (
	select occurence=max(occurence)
	from #t_queries
	where [event_hashbytes] = tx.[event_hashbytes]
) o

where tx.occurence = 1 
and x.[event_hash] is null;

*/