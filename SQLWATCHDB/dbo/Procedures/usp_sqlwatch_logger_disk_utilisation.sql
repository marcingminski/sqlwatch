CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_disk_utilisation]
AS
set nocount on;

declare @snapshot_type tinyint = 2
declare	@product_version nvarchar(128)
declare @product_version_major decimal(10,2)
declare @product_version_minor decimal(10,2)
declare @sql varchar(max)

set @product_version = convert(nvarchar(128),serverproperty('productversion'));
select @product_version_major = substring(@product_version, 1,charindex('.', @product_version) + 1 )
	  ,@product_version_minor = parsename(convert(varchar(32), @product_version), 2);
--------------------------------------------------------------------------------------------------------------
-- set the basics
--------------------------------------------------------------------------------------------------------------
declare @snapshot_time datetime = getdate();
insert into [dbo].[sqlwatch_logger_snapshot_header] (snapshot_time, snapshot_type_id)
values (@snapshot_time, @snapshot_type)

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

if @product_version_major >= 13
/*	since SQL 2016 Microsoft have improved sp_spaceused which now returns one recordset making it easier
	to insert into tables */
	begin
		insert into @spaceused
			exec sp_MSforeachdb 'use [?]; exec sp_spaceused @oneresultset = 1;'
	end
else
	begin
	/*	pre 2016 however is not all that easy. sp_spaceused will return multiple resultsets making it impossible
		to insert into a table. The below is more or less what sp_spaceused is doing */
		insert into @spaceused
		exec sp_MSforeachdb 'USE [?];
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
			exec sp_MSforeachdb '
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
insert into [dbo].[sqlwatch_logger_disk_utilisation_database]
select 
	  su.[database_name]
	, [database_create_date] = db.create_date
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
	, [snapshot_type_id] = @snapshot_type
	, @@SERVERNAME
from @spaceused su
inner join @logspace ls
	on su.[database_name] = ls.[database_name] collate database_default
inner join sys.databases db
	on db.[name] = su.[database_name] collate database_default
/*	join on sqlwatch database list otherwise it will fail
	for newly created databases not yet added to the list */
inner join [dbo].[sqlwatch_meta_database] swd
	on swd.[database_name] = db.[name] collate database_default
	and swd.[database_create_date] = db.[create_date]
