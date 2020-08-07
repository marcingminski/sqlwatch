CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_index_histogram]

as

/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	[usp_sqlwatch_logger_index_histogram]

 Description:
	Collect index histogram.

 Parameters
	
 Author:
	Marcin Gminski

 Change Log:
	1.0		2018-08		- Marcin Gminski, Initial version
	1.1		2020-03-18	- Marcin Gminski, move explicit transaction after header to fix https://github.com/marcingminski/sqlwatch/issues/155
-------------------------------------------------------------------------------------------------------------------
*/

set xact_abort on
set nocount on

declare @snapshot_type_id tinyint = 14,
		@snapshot_time datetime,
		@database_name sysname,
		@sql varchar(max),
		@object_id int,
		@index_name sysname,
		@index_id int,
		@object_name nvarchar(256),
		@sqlwatch_database_id smallint,
		@sqlwatch_table_id int,
		@sqlwatch_index_id int

declare @indextype as table (
	is_index_hierarchical bit,
	is_index_timestamp bit
)


create table #stats_hierarchical (
	[database_name] sysname default 'fe92qw0fa_dummy',
	[object_name] sysname default 'fe92qw0fa_dummy',
	index_name sysname default 'fe92qw0fa_dummy',
	index_id int,
	RANGE_HI_KEY hierarchyid,
	RANGE_ROWS real,
	EQ_ROWS real,
	DISTINCT_RANGE_ROWS real,
	AVG_RANGE_ROWS real,
	[collection_time] datetime,
	[sqlwatch_database_id] smallint,
	[sqlwatch_table_id] int,
	[sqlwatch_index_id] int
)

/* new temp table because of  https://github.com/marcingminski/sqlwatch/issues/119 */ 
create table #stats_timestamp (
	[database_name] sysname default 'fe92qw0fa_dummy',
	[object_name] sysname default 'fe92qw0fa_dummy',
	index_name sysname default 'fe92qw0fa_dummy',
	index_id int,
	/*
		timestamp is a rowversion column - a binary "counter" to identify that the row has been modified. 
		it is unlikely to have index or/and stats on the rowversion column but we have seen it happen. (yay vendor apps!)
		so we have to be able to handle it. 		
		Anyway, timestamp (aka rowversion) will implicitly convert to varchar and datetime.
		when converted to varchar the value will be empty string, and when converted to datetime it will simply add the counter value to 1900-01-01
		and will show relatively random date. I don't either will be of any use and I'd be actually tempted to just not collect any stats from indexes on these columns 
		but happy to wait for community advice and expertise. 
	*/
	RANGE_HI_KEY datetime, 
	RANGE_ROWS real,
	EQ_ROWS real,
	DISTINCT_RANGE_ROWS real,
	AVG_RANGE_ROWS real,
	[collection_time] datetime,
	[sqlwatch_database_id] smallint,
	[sqlwatch_table_id] int,
	[sqlwatch_index_id] int
)

create table #stats (
	[database_name] sysname default 'fe92qw0fa_dummy',
	[object_name] sysname default 'fe92qw0fa_dummy',
	index_name sysname default 'fe92qw0fa_dummy',
	index_id int,
	RANGE_HI_KEY sql_variant,
	RANGE_ROWS real,
	EQ_ROWS real,
	DISTINCT_RANGE_ROWS real,
	AVG_RANGE_ROWS real,
	[collection_time] datetime,
	[sqlwatch_database_id] smallint,
	[sqlwatch_table_id] int,
	[sqlwatch_index_id] int
)

declare @is_index_hierarchical bit
declare @is_index_timestamp bit  

set  @snapshot_type_id = 15

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

	inner join [dbo].[vw_sqlwatch_sys_databases] sdb
		on sdb.name = md.database_name collate database_default
		and sdb.create_date = md.database_create_date

	/*	Index histograms can be very large and since its only required for a very specific performance tuning, 
		we are only going to collect those exclusively included for collection	*/
	inner join [dbo].[sqlwatch_config_include_index_histogram] ih
		on md.[database_name] like parsename(ih.object_name_pattern,3)
		and mt.table_name like parsename(ih.object_name_pattern,2) + '.' + parsename(ih.object_name_pattern,1)
		and mi.index_name like ih.index_name_pattern

	left join [dbo].[sqlwatch_config_exclude_database] ed
		on md.[database_name] like ed.database_name_pattern
		and ed.snapshot_type_id = @snapshot_type_id

	where ed.snapshot_type_id is null

open c_index

fetch next from c_index
into @database_name, @object_name, @index_name, @index_id, @sqlwatch_database_id, @sqlwatch_table_id, @sqlwatch_index_id

while @@FETCH_STATUS = 0
	begin
		delete from @indextype
		select @is_index_hierarchical = 0, @is_index_timestamp = 0

		set @sql = 'use [' + @database_name + ']; 
			select
				is_index_hierarchical = case when tp.name = ''hierarchyid'' then 1 else 0 end,
				is_index_timestamp = case when tp.name = ''timestamp'' then 1 else 0 end
			from sys.schemas s
			inner join sys.tables t 
				on s.schema_id = t.schema_id
			inner join sys.indexes i 
				on i.object_id = t.object_id
			inner join sys.index_columns ic 
				on ic.index_id = i.index_id 
				and ic.object_id = i.object_id
				/* only the leading column is used to build histogram 
				   https://dba.stackexchange.com/a/182250 */
				and ic.index_column_id = 1
			inner join sys.columns c 
				on c.column_id = ic.column_id 
				and c.object_id = ic.object_id
			inner join sys.types tp
				on tp.system_type_id = c.system_type_id
				and tp.user_type_id = c.user_type_id
			where i.name = ''' + @index_name + '''
			and s.name + ''.'' + t.name = ''' + @object_name + ''''
		insert into @indextype(is_index_hierarchical, is_index_timestamp)
		exec (@sql)

		select 
			@is_index_hierarchical = is_index_hierarchical,
			@is_index_timestamp = is_index_timestamp
		from @indextype


		--set @object_name = object_schema_name(@object_id) + '.' + object_name(@object_id)
		set @sql = 'use [' + @database_name + ']; 
--extra check if the table and index still exist. since we are collecting histogram for indexes already collected in sqlwatch,
--there could be a situation where index was deleted from Sql Server before SQLWATCH was upated and the below would have thrown an error.
if exists (
		select *
		from sys.indexes 
		where object_id = object_id(''' + @object_name + ''')
		and name=''' + @index_name + ''')
	begin
		dbcc show_statistics (''' + @object_name + ''',''' + @index_name + ''') with  HISTOGRAM
		Print ''['' + convert(varchar(23),getdate(),121) + ''] Collecting index histogram for index: ' + @index_name + '''
	end'

		if @is_index_hierarchical = 1
			begin
				insert into #stats_hierarchical (RANGE_HI_KEY,RANGE_ROWS,EQ_ROWS,DISTINCT_RANGE_ROWS,AVG_RANGE_ROWS)
				exec (@sql)

				update #stats_hierarchical
					set [database_name] = @database_name
						, [object_name] = @object_name
						, index_name = @index_name
						, index_id = @index_id
						, [collection_time] = getutcdate()
						, [sqlwatch_database_id] = @sqlwatch_database_id
						, [sqlwatch_table_id] = @sqlwatch_table_id
						, [sqlwatch_index_id] = @sqlwatch_index_id
				where index_name = 'fe92qw0fa_dummy'
			end
		else if @is_index_timestamp = 1
			begin
				insert into #stats_timestamp (RANGE_HI_KEY,RANGE_ROWS,EQ_ROWS,DISTINCT_RANGE_ROWS,AVG_RANGE_ROWS)
				exec (@sql)

				update #stats_timestamp
					set [database_name] = @database_name
						, [object_name] = @object_name
						, index_name = @index_name
						, index_id = @index_id
						, [collection_time] = getutcdate()
						, [sqlwatch_database_id] = @sqlwatch_database_id
						, [sqlwatch_table_id] = @sqlwatch_table_id
						, [sqlwatch_index_id] = @sqlwatch_index_id
				where index_name = 'fe92qw0fa_dummy'
			end
		else
			begin
				insert into #stats (RANGE_HI_KEY,RANGE_ROWS,EQ_ROWS,DISTINCT_RANGE_ROWS,AVG_RANGE_ROWS)
				exec (@sql)

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
			end

		fetch next from c_index
		into @database_name, @object_name, @index_name, @index_id, @sqlwatch_database_id, @sqlwatch_table_id, @sqlwatch_index_id
	end

close c_index
deallocate c_index 


	exec [dbo].[usp_sqlwatch_internal_insert_header] 
		@snapshot_time_new = @snapshot_time OUTPUT,
		@snapshot_type_id = @snapshot_type_id

begin tran

	insert into [dbo].[sqlwatch_logger_index_histogram](
		[sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id],
		RANGE_HI_KEY, RANGE_ROWS, EQ_ROWS, DISTINCT_RANGE_ROWS, AVG_RANGE_ROWS,
		[snapshot_time], [snapshot_type_id], [collection_time])
	select
		st.[sqlwatch_database_id],
		st.[sqlwatch_table_id],
		st.[sqlwatch_index_id],
		convert(nvarchar(max),st.RANGE_HI_KEY),
		RANGE_ROWS = convert(real,st.RANGE_ROWS),
		EQ_ROWS = convert(real,st.EQ_ROWS),
		DISTINCT_RANGE_ROWS = convert(real,st.DISTINCT_RANGE_ROWS),
		AVG_RANGE_ROWS = convert(real,st.AVG_RANGE_ROWS),
		[snapshot_time] = @snapshot_time,
		[snapshot_type_id] = @snapshot_type_id,
		[collection_time]
	from #stats st

	insert into [dbo].[sqlwatch_logger_index_histogram](
			[sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id],
		RANGE_HI_KEY, RANGE_ROWS, EQ_ROWS, DISTINCT_RANGE_ROWS, AVG_RANGE_ROWS,
		[snapshot_time], [snapshot_type_id], [collection_time])
	select
		st.[sqlwatch_database_id],
		st.[sqlwatch_table_id],
		st.[sqlwatch_index_id],
		convert(nvarchar(max),st.RANGE_HI_KEY),
		RANGE_ROWS = convert(real,st.RANGE_ROWS),
		EQ_ROWS = convert(real,st.EQ_ROWS),
		DISTINCT_RANGE_ROWS = convert(real,st.DISTINCT_RANGE_ROWS),
		AVG_RANGE_ROWS = convert(real,st.AVG_RANGE_ROWS),
		[snapshot_time] = @snapshot_time,
		[snapshot_type_id] = @snapshot_type_id,
		[collection_time]
	from #stats_hierarchical st

	insert into [dbo].[sqlwatch_logger_index_histogram](
			[sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id],
		RANGE_HI_KEY, RANGE_ROWS, EQ_ROWS, DISTINCT_RANGE_ROWS, AVG_RANGE_ROWS,
		[snapshot_time], [snapshot_type_id], [collection_time])
	select
		st.[sqlwatch_database_id],
		st.[sqlwatch_table_id],
		st.[sqlwatch_index_id],
		convert(nvarchar(max),st.RANGE_HI_KEY),
		RANGE_ROWS = convert(real,st.RANGE_ROWS),
		EQ_ROWS = convert(real,st.EQ_ROWS),
		DISTINCT_RANGE_ROWS = convert(real,st.DISTINCT_RANGE_ROWS),
		AVG_RANGE_ROWS = convert(real,st.AVG_RANGE_ROWS),
		[snapshot_time] = @snapshot_time,
		[snapshot_type_id] = @snapshot_type_id,
		[collection_time]
	from #stats_timestamp st


commit tran
