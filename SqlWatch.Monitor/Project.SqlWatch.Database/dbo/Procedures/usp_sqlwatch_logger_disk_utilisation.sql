CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_disk_utilisation]
	@databases varchar(max) = 'ALL',
	@ignore_global_exclusion bit = 0
AS

/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	[usp_sqlwatch_logger_disk_utilisation]

 Description:
	Collect Disk utilisation.

 Parameters
	
 Author:
	Marcin Gminski

 Change Log:
	1.0		2018-08		- Marcin Gminski, Initial version
	1.1		2020-03-18	- Marcin Gminski, move explicit transaction after header to fix https://github.com/marcingminski/sqlwatch/issues/155
	1.2		2020-03-22	- Marcin Gminski, moved off sp_MSforeachdb
	1.3		2020-05-16  - Marcin Gminski, https://github.com/marcingminski/sqlwatch/issues/165. 
			NOTES: The [dbo].[usp_sqlwatch_internal_foreachdb] could simply execute a SQL that inserts directly into 
			the destination table [dbo].[sqlwatch_logger_disk_utilisation_database]. There is room for improevemnt here.
-------------------------------------------------------------------------------------------------------------------
*/

set nocount on;

set xact_abort on


declare @snapshot_type_id tinyint = 2,
		@snapshot_time datetime2(0),
		@product_version nvarchar(128),
		@product_version_major decimal(10,2),
		@product_version_minor decimal(10,2),
		@sql varchar(max)

select @product_version = convert(nvarchar(128),serverproperty('productversion'));
select @product_version_major = substring(@product_version, 1,charindex('.', @product_version) + 1 )
	  ,@product_version_minor = parsename(convert(varchar(32), @product_version), 2);

--------------------------------------------------------------------------------------------------------------
-- get new header
--------------------------------------------------------------------------------------------------------------
exec [dbo].[usp_sqlwatch_internal_insert_header] 
	@snapshot_time_new = @snapshot_time OUTPUT,
	@snapshot_type_id = @snapshot_type_id

--------------------------------------------------------------------------------------------------------------
-- get sp_spaceused
--------------------------------------------------------------------------------------------------------------
declare @spaceused table (
		[database_name] nvarchar(128),
		[database_size] varchar(18),
		[unallocated_space] varchar(18),
		[reserved] varchar(18),
		[data] varchar(18),
		[index_size] varchar(18),
		[unused] varchar(18)
)

--https://github.com/marcingminski/sqlwatch/issues/165
declare @spaceused_extent table (
	[database_name] nvarchar(128),
	unallocated_extent_page_count bigint,
	allocated_extent_page_count bigint,
	version_store_reserved_page_count bigint,
	user_object_reserved_page_count bigint,
	internal_object_reserved_page_count bigint,
	mixed_extent_page_count bigint,
	unique clustered ([database_name]) 
)

insert into @spaceused_extent
exec [dbo].[usp_sqlwatch_internal_foreachdb] 
	@snapshot_type_id = @snapshot_type_id,
	@calling_proc_id = @@PROCID,
	@databases = @databases,
	@command =  'USE [?];
select 
	 DB_NAME()
	,sum(a.unallocated_extent_page_count) 
    ,sum(a.allocated_extent_page_count) 
    ,sum(a.version_store_reserved_page_count) 
    ,sum(a.user_object_reserved_page_count) 
    ,sum(a.internal_object_reserved_page_count) 
    ,sum(a.mixed_extent_page_count)
from sys.dm_db_file_space_usage a'


if @product_version_major >= 13
/*	since SQL 2016 Microsoft have improved sp_spaceused which now returns one recordset making it easier
	to insert into tables */
	begin
		insert into @spaceused
			exec [dbo].[usp_sqlwatch_internal_foreachdb] @command = 'use [?]; exec sp_spaceused @oneresultset = 1;'
				, @snapshot_type_id = @snapshot_type_id
				, @calling_proc_id = @@PROCID
				, @databases = @databases
	end
else
	begin
	/*	pre 2016 however is not all that easy. sp_spaceused will return multiple resultsets making it impossible
		to insert into a table. The below is more or less what sp_spaceused is doing */
		insert into @spaceused
		exec [dbo].[usp_sqlwatch_internal_foreachdb] 
			@snapshot_type_id = @snapshot_type_id,
			@calling_proc_id = @@PROCID,
			@databases = @databases,
			@command =  'USE [?];
		declare  @id	int			
				,@type	character(2) 
				,@pages	bigint
				,@dbname sysname
				,@dbsize bigint
				,@logsize bigint
				,@reservedpages  bigint
				,@usedpages  bigint
				,@rowCount bigint

			select 
				  @dbsize = sum(convert(bigint,case when status & 64 = 0 then size else 0 end))
				, @logsize = sum(convert(bigint,case when status & 64 <> 0 then size else 0 end))
				from dbo.sysfiles

			select 
				@reservedpages = sum(a.total_pages),
				@usedpages = sum(a.used_pages),
				@pages = sum(
						case
							-- XML-Index and FT-Index and semantic index internal tables are not considered "data", but is part of "index_size"
							when it.internal_type IN (202,204,207,211,212,213,214,215,216,221,222,236) then 0
							when a.type <> 1 and p.index_id < 2 then a.used_pages
							when p.index_id < 2 then a.data_pages
							else 0
						end
					)
			from sys.partitions p join sys.allocation_units a on p.partition_id = a.container_id
				left join sys.internal_tables it on p.object_id = it.object_id

			select 
				database_name = db_name(),
				database_size = ltrim(str((convert (dec (15,2),@dbsize) + convert (dec (15,2),@logsize)) 
					* 8192 / 1048576,15,2) + '' MB''),
				''unallocated space'' = ltrim(str((case when @dbsize >= @reservedpages then
					(convert (dec (15,2),@dbsize) - convert (dec (15,2),@reservedpages)) 
					* 8192 / 1048576 else 0 end),15,2) + '' MB''),
				reserved = ltrim(str(@reservedpages * 8192 / 1024.,15,0) + '' KB''),
				data = ltrim(str(@pages * 8192 / 1024.,15,0) + '' KB''),
				index_size = ltrim(str((@usedpages - @pages) * 8192 / 1024.,15,0) + '' KB''),
				unused = ltrim(str((@reservedpages - @usedpages) * 8192 / 1024.,15,0) + '' KB'')
				'
	end

--------------------------------------------------------------------------------------------------------------
-- get log usage
--------------------------------------------------------------------------------------------------------------
declare @logspace_SQL2008 table (
	[database_name] sysname,
	[log_space_mb] decimal(18,2),
	[log_space_used_perc] real,
	[status] bit
)

declare @logspace table (
	[database_name] sysname,
	[total_log_size_in_bytes] bigint,
	[used_log_space_in_bytes] bigint
)

if @product_version_major < 11
	begin
		insert into @logspace_SQL2008
			exec ('DBCC SQLPERF(LOGSPACE);')

		/* make into a 2012 format */
		insert into @logspace
		select 
			[database_name],
			[total_log_size_in_bytes] = [log_space_mb] * 1024.0 * 1024.0,
			[used_log_space_in_bytes] = ([log_space_mb] * [log_space_used_perc] / 100.0) * 1024.0 * 1024.0
		from @logspace_SQL2008
	end
else
	begin
		--https://github.com/marcingminski/sqlwatch/issues/90
		--https://support.microsoft.com/en-gb/help/4088901/fix-assertion-failure-for-sys-dm-db-log-space-usage-on-database
		--exclude log collection for database snapshots. Snapshots have no logs anyway.
		insert into @logspace
			exec [dbo].[usp_sqlwatch_internal_foreachdb] 
				@snapshot_type_id = @snapshot_type_id,
				@calling_proc_id = @@PROCID,		
				@databases = @databases,
				@command =  '
				use [?]
				if exists (select 1 from sys.databases where name = ''?'' 
							and source_database_id is null)
					begin
						select 
							''?'',
							[total_log_size_in_bytes],
							[used_log_space_in_bytes]
						from sys.dm_db_log_space_usage
					end'
	end


--------------------------------------------------------------------------------------------------------------
-- combine results and insert into the table
--------------------------------------------------------------------------------------------------------------
begin tran
	insert into [dbo].[sqlwatch_logger_disk_utilisation_database]
	select 
		--  su.[database_name]
		--, [database_create_date] = db.create_date
		[sqlwatch_database_id] = swd.[sqlwatch_database_id]
		/*	
			conversion from sp_spaceused MiB format to bytes so we have consistent units 
			to test that this gives us an exact number:
			sp_spaceused returns 7.63 MB for master database.
			our conversion below gives us 8000634 bytes -> covnert back to MB: 
				8000634 / 1024 / 1024 = 7.6299 MB
			Try: http://www.wolframalpha.com/input/?i=8000634+bytes+in+MiB 
		*/
		, [database_size_bytes] = convert(bigint,convert(decimal(19,2),replace([database_size],' MB','')) * 1024 * 1024)
		, [unallocated_space_bytes] = convert(bigint,convert(decimal(19,2),replace([unallocated_space],' MB','')) * 1024.0 * 1024.0)
		, [reserved_bytes] = convert(bigint,convert(decimal(19,2),replace([reserved],' KB','')) * 1024.0)
		, [data_bytes] = convert(bigint,convert(decimal(19,2),replace([data],' KB','')) * 1024.0)
		, [index_size_bytes] = convert(bigint,convert(decimal(19,2),replace([index_size],' KB','')) * 1024.0)
		, [unused_bytes] = convert(bigint,convert(decimal(19,2),replace([unused],' KB','')) * 1024.0)
		, ls.[total_log_size_in_bytes]
		, ls.[used_log_space_in_bytes]
		, [snapshot_time] = @snapshot_time
		, [snapshot_type_id] = @snapshot_type_id
		, @@SERVERNAME

		, [unallocated_extent_page_count] = suex.[unallocated_extent_page_count]
		, [allocated_extent_page_count] = suex.[allocated_extent_page_count]
		, [version_store_reserved_page_count] = suex.[version_store_reserved_page_count]
		, [user_object_reserved_page_count] = suex.[user_object_reserved_page_count]
		, [internal_object_reserved_page_count] = suex.[internal_object_reserved_page_count]
		, [mixed_extent_page_count] = suex.[mixed_extent_page_count]

	from @spaceused su
	inner join @logspace ls
		on su.[database_name] = ls.[database_name] collate database_default
	inner join vw_sqlwatch_sys_databases db
		on db.[name] = su.[database_name] collate database_default
	/*	join on sqlwatch database list otherwise it will fail
		for newly created databases not yet added to the list */
	inner join [dbo].[sqlwatch_meta_database] swd
		on swd.[database_name] = db.[name] collate database_default
		and swd.[database_create_date] = db.[create_date]
		and swd.sql_instance = @@SERVERNAME

	left join @spaceused_extent suex
		on su.[database_name] = suex.[database_name] collate database_default

	left join [dbo].[sqlwatch_config_exclude_database] ed
		on swd.[database_name] like ed.database_name_pattern
		and ed.snapshot_type_id = @snapshot_type_id

	where ed.snapshot_type_id is null

commit tran
