CREATE PROCEDURE [dbo].[usp_logger_disk_utilisation]
AS
set nocount on;

declare @snapshot_type tinyint = 2
declare	@product_version nvarchar(128)
declare @product_version_major decimal(10,2)
declare @product_version_minor decimal(10,2)

set @product_version = convert(nvarchar(128),serverproperty('productversion'));
select @product_version_major = substring(@product_version, 1,charindex('.', @product_version) + 1 )
	  ,@product_version_minor = parsename(convert(varchar(32), @product_version), 2);
--------------------------------------------------------------------------------------------------------------
-- set the basics
--------------------------------------------------------------------------------------------------------------
declare @snapshot_time datetime = getdate();
insert into [dbo].[sql_perf_mon_snapshot_header]
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
insert into @spaceused
    exec sp_MSforeachdb 'use [?]; exec sp_spaceused @oneresultset = 1;'

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
		insert into @logspace
			exec sp_MSforeachdb '
				use [?]
				select 
					''?'',
					[total_log_size_in_bytes],
					[used_log_space_in_bytes]
				from sys.dm_db_log_space_usage'
	end


--------------------------------------------------------------------------------------------------------------
-- combine results and insert into the table
--------------------------------------------------------------------------------------------------------------
insert into [dbo].[logger_disk_utilisation_database]
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
from @spaceused su
inner join @logspace ls
	on su.[database_name] = ls.[database_name]
inner join sys.databases db
	on db.[name] = su.[database_name]
/*	join on sqlwatch database list otherwise it will fail
	for newly created databases not yet added to the list */
inner join [dbo].[sql_perf_mon_database] swd
	on swd.[database_name] = db.[name]
	and swd.[database_create_date] = db.[create_date]
