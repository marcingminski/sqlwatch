CREATE PROCEDURE [dbo].[sp_sql_perf_mon_add_database]
as
	/* this procedure adds databse to our "dimension" table:
	[dbo].[sql_perf_mon_database]
   
   this is only required so we can filter by database dimension
   in the report. The data collection happens for all databases 
   Currently, databases are being added to the above table
   during installation. This is not good enough as when new
   database is being created it will never appear on the report.

   This procedure will be scheduled to run periodically to add
   any missing databases. It will also be triggered during install 
   to maintain one piece of code */

	set nocount on;

	declare @databases table (
		[database_name] sysname not null,
		[database_create_date] datetime not null default '1970-01-01',
		primary key clustered (
		 [database_name],[database_create_date]
	 )
)

	insert into @databases
	select [name], [create_date]
	from sys.databases
	union all
	/* mssqlsystemresource database appears in the performance counters
	so we need it as a dimensions to be able to filter in the report */
	select 'mssqlsystemresource', '1970-01-01'
	
	;merge [dbo].[sql_perf_mon_database] as target
	using @databases as source
		on (
				source.[database_name] = target.[database_name]
			and source.[database_create_date] = target.[database_create_date]
		)
	/* dropped databases are going to be updated to current = 0 */
	when not matched by source then
		update set [database_current] = 0
	/* new databases are going to be inserted */
	when not matched by target then
		insert ([database_name], [database_create_date])
		values (source.[database_name], source.[database_create_date]);

	/*	the above only accounts for databases that have been removed and re-added
		if you rename database it will be treated as if it was removed and new
		database created so you will lose history continuation. Why would you
		rename a database anyway */