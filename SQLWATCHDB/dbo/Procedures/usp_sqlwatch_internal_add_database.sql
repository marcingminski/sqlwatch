CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_database]
as
	set nocount on;

	declare @databases table (
		[database_name] sysname not null,
		[database_create_date] datetime not null default '1970-01-01',
		[sql_instance] varchar(32) not null
		primary key clustered (
		 [database_name],[database_create_date], [sql_instance]
	 )
)

	insert into @databases
	select [name], [create_date], [sql_instance] = @@SERVERNAME
	from sys.databases
	union all
	/* mssqlsystemresource database appears in the performance counters
	so we need it as a dimensions to be able to filter in the report */
	select 'mssqlsystemresource', '1970-01-01', @@SERVERNAME
	

	/*	using database_create_data to distinguish databases that have been dropped and re-created 
		this is particulary useful when doing performance testing and we are re-creating test databases throughout the process and want to compare them later.
	*/
	;merge [dbo].[sqlwatch_meta_database] as target
	using @databases as source
		on (
				source.[database_name] = target.[database_name]
			and source.[database_create_date] = target.[database_create_date]
			and source.[sql_instance] = target.[sql_instance]
		)
	/* dropped databases are going to be updated to current = 0 */
	--when not matched by source and target.sql_instance = @@SERVERNAME then
	--	update set deleted_when = GETUTCDATE()
	/* new databases are going to be inserted */
	when not matched by target then
		insert ([database_name], [database_create_date], [sql_instance])
		values (source.[database_name], source.[database_create_date], source.[sql_instance]);

	/*	the above only accounts for databases that have been removed and re-added
		if you rename database it will be treated as if it was removed and new
		database created so you will lose history continuation. Why would you
		rename a database anyway */