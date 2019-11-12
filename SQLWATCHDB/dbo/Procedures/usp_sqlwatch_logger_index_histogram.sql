CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_index_histogram]
as

set xact_abort on
begin tran

declare @snapshot_type tinyint = 14
declare @database_name sysname
declare @sql varchar(max)

declare @object_id int
declare @index_name sysname
declare @index_id int
declare @object_name nvarchar(256)

declare @sqlwatch_database_id smallint
declare @sqlwatch_table_id int
declare @sqlwatch_index_id int

set nocount on ;

/* step 2, collect index statistsics and histograms for the newly collected indexes */
create table #stats (
	[database_name] sysname default 'fe92qw0fa_dummy',
	[object_name] sysname default 'fe92qw0fa_dummy',
	index_name sysname default 'fe92qw0fa_dummy',
	index_id int,
	RANGE_HI_KEY sql_variant,
	RANGE_ROWS sql_variant,
	EQ_ROWS sql_variant,
	DISTINCT_RANGE_ROWS sql_variant,
	AVG_RANGE_ROWS sql_variant,
	[collection_time] datetime,
	[sqlwatch_database_id] smallint,
	[sqlwatch_table_id] int,
	[sqlwatch_index_id] int
)


set @snapshot_type = 15

declare c_index cursor for
select md.[database_name], table_name=mt.table_name , index_name = mi.index_name, mi.index_id, mi.sqlwatch_database_id, mi.sqlwatch_table_id, mi.sqlwatch_index_id
from [dbo].[sqlwatch_meta_index] mi

	inner join [dbo].[sqlwatch_meta_table] mt
		on mt.sqlwatch_database_id = mi.sqlwatch_database_id
		and mt.sql_instance = mi.sql_instance
		and mt.sqlwatch_table_id = mi.sqlwatch_table_id

	inner join [dbo].[sqlwatch_meta_database] md
		on md.sql_instance = mi.sql_instance
		and md.sqlwatch_database_id = mi.sqlwatch_database_id

	inner join sys.databases sdb
		on sdb.name = md.database_name collate database_default
		and sdb.create_date = md.database_create_date

	/* https://github.com/marcingminski/sqlwatch/issues/108 */
	--begin hadr aware and db online 
	   left join sys.dm_hadr_availability_replica_states hars 
			on sdb.replica_id = hars.replica_id
	   left join sys.availability_replicas ar 
			on sdb.replica_id = ar.replica_id
	--end hadr aware and db online ? 

where mi.[sql_instance] = @@SERVERNAME
and mi.date_deleted is null

--begin hadr aware and db online ?
and database_id > 4 
and state_desc = 'ONLINE'
and (  
		(hars.role_desc = 'PRIMARY' or hars.role_desc is null)
	 or (hars.role_desc = 'SECONDARY' and ar.secondary_role_allow_connections_desc IN ('READ_ONLY','ALL'))
	 )
and [name] not like '%ReportServer%'
--end hadr aware and db online ? 


open c_index

fetch next from c_index
into @database_name, @object_name, @index_name, @index_id, @sqlwatch_database_id, @sqlwatch_table_id, @sqlwatch_index_id

while @@FETCH_STATUS = 0
	begin
		--set @object_name = object_schema_name(@object_id) + '.' + object_name(@object_id)
		set @sql = 'use [' + @database_name + ']; 
--extra check if the table and index still exist. since we are collecting histogram for indexes already collected in sqlwatch,
--there could be a situation where index was deleted from Sql Server before SQLWATCH was upated and the below would have thrown an error.
if object_id(''' + @object_name + ''') is not null and object_id(''' + @index_name + ''') is not null
	begin
		dbcc show_statistics (''' + @object_name + ''',''' + @index_name + ''') with  HISTOGRAM
		Print ''['' + convert(varchar(23),getdate(),121) + ''] Collecting index histogram for idnex: ' + @index_name + '''
	end'

		insert into #stats (RANGE_HI_KEY,RANGE_ROWS,EQ_ROWS,DISTINCT_RANGE_ROWS,AVG_RANGE_ROWS)
		exec (@sql)
		--print 'Getting stats for: ' + @database_name

		update #stats
			set [database_name] = @database_name
				, [object_name] = @object_name
				, index_name = @index_name
				, index_id = @index_id
				, [collection_time] = getutcdate()
				, [sqlwatch_database_id] = @sqlwatch_database_id
				, [sqlwatch_table_id] = @sqlwatch_table_id
				, [sqlwatch_index_id] = @sqlwatch_index_id
		where index_name = 'fe92qw0fa_dummy'

		fetch next from c_index
		into @database_name, @object_name, @index_name, @index_id, @sqlwatch_database_id, @sqlwatch_table_id, @sqlwatch_index_id
	end

close c_index
deallocate c_index 

	declare @snapshot_time datetime = getutcdate();
	insert into [dbo].[sqlwatch_logger_snapshot_header] (snapshot_time, snapshot_type_id)
	values (@snapshot_time, @snapshot_type)

	insert into [dbo].[sqlwatch_logger_index_usage_stats_histogram](
		 [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id],
		RANGE_HI_KEY, RANGE_ROWS, EQ_ROWS, DISTINCT_RANGE_ROWS, AVG_RANGE_ROWS,
		[snapshot_time], [snapshot_type_id], [collection_time])
	select
		st.[sqlwatch_database_id],
		st.[sqlwatch_table_id],
		st.[sqlwatch_index_id],
		--st.[object_name],
		--st.[index_name],
		--st.[index_id],
		convert(nvarchar(max),st.RANGE_HI_KEY),
		RANGE_ROWS = convert(real,st.RANGE_ROWS),
		EQ_ROWS = convert(real,st.EQ_ROWS),
		DISTINCT_RANGE_ROWS = convert(real,st.DISTINCT_RANGE_ROWS),
		AVG_RANGE_ROWS = convert(real,st.AVG_RANGE_ROWS),
		[snapshot_time] = @snapshot_time,
		[snapshot_type_id] = @snapshot_type,
		[collection_time]
	from #stats st

commit tran