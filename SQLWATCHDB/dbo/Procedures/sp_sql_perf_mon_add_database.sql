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
		[database_name] sysname primary key
	)

	insert into @databases
	select [name] from sys.databases
	union all
	/* mssqlsystemresource database appears in the performance counters
	so we need it as a dimensions to be able to filter in the report */
	select 'mssqlsystemresource'

   	insert into [dbo].[sql_perf_mon_database]
	select s.[database_name] 
	from @databases s
	left join [dbo].[sql_perf_mon_database] t
		on s.[database_name] = t.[database_name]
	where t.[database_name] is null
	