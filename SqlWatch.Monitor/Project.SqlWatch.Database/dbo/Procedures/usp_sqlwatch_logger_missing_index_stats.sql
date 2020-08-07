CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_missing_index_stats]
AS

/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	[dbo].[usp_sqlwatch_logger_missing_index_stats]

 Description:
	Captures Missing Indexes

 Parameters
	
 Author:
	Marcin Gminski

 Change Log:
	1.0		2018-09-22	- Colin Douglas:	Initial Version
	1.1		2019-11-17	- Marcin Gminski:	Exclude idle wait stats.
	1.2		2019-11-24	- Marcin Gminski:	Replace sys.databses with dbo.vw_sqlwatch_sys_databases
	1.3		2020-03-18	- Marcin Gminski,	move explicit transaction after header to fix https://github.com/marcingminski/sqlwatch/issues/155
-------------------------------------------------------------------------------------------------------------------
*/

set xact_abort on

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    
	--------------------------------------------------------------------------------------------------------------
    -- variables
	--------------------------------------------------------------------------------------------------------------
	declare @snapshot_time datetime,
			@snapshot_type_id tinyint = 3

	exec [dbo].[usp_sqlwatch_internal_insert_header] 
		@snapshot_time_new = @snapshot_time OUTPUT,
		@snapshot_type_id = @snapshot_type_id

	--only enterprise and developer will allow online index build/rebuild
	declare @allows_online_index bit
	select @allows_online_index = case 
			when 
					convert(varchar(4000),serverproperty('Edition')) like 'Enterprise%' 
				or	convert(varchar(4000),serverproperty('Edition')) like 'Developer%'
			then 1
			else 0
		end

	--------------------------------------------------------------------------------------------------------------
	-- get missing indexes
	--------------------------------------------------------------------------------------------------------------
begin tran

	insert into [dbo].[sqlwatch_logger_index_missing_stats] ([sqlwatch_database_id],
		[sqlwatch_table_id], [sqlwatch_missing_index_id],[snapshot_time], [last_user_seek], [unique_compiles],
		[user_seeks], [user_scans], [avg_total_user_cost], [avg_user_impact], [snapshot_type_id],[sql_instance])
	select 
		--[server_name] = @@servername ,
		[sqlwatch_database_id] = db.[sqlwatch_database_id], 
		[sqlwatch_table_id] = mt.[sqlwatch_table_id],
		[sqlwatch_missing_index_id] = mii.sqlwatch_missing_index_id,

		--[database_create_date] = db.[database_create_date],
		--[object_name] = parsename(mi.[statement],2) + '.' + parsename(mi.[statement],1), 
		[snapshot_time] = @snapshot_time,
		igs.[last_user_seek],
		igs.[unique_compiles], 
		igs.[user_seeks], 
		igs.[user_scans], 
		igs.[avg_total_user_cost], 
		igs.[avg_user_impact],
		[snapshot_type_id] = @snapshot_type_id,
		@@SERVERNAME
	from sys.dm_db_missing_index_groups ig 

		inner join sys.dm_db_missing_index_group_stats igs 
			on igs.group_handle = ig.index_group_handle 

		inner join sys.dm_db_missing_index_details mi 
			on ig.index_handle = mi.index_handle

		inner join dbo.vw_sqlwatch_sys_databases sdb
			on sdb.[name] = db_name(mi.[database_id])

		inner join [dbo].[sqlwatch_meta_database] db
			on db.[database_name] = db_name(mi.[database_id])
			and db.[database_create_date] = sdb.[create_date]
			and db.sql_instance = @@SERVERNAME

		inner join [dbo].[sqlwatch_meta_table] mt
			on mt.sql_instance = db.sql_instance
			and mt.sqlwatch_database_id = db.sqlwatch_database_id
			and mt.table_name = parsename(mi.[statement],2) + '.' + parsename(mi.[statement],1)

		inner join [dbo].[sqlwatch_meta_index_missing] mii
			on mii.sqlwatch_database_id = db.sqlwatch_database_id
			and mii.sqlwatch_table_id = mt.sqlwatch_table_id
			and mii.sql_instance = mt.sql_instance
			and mii.index_handle = ig.index_handle
			and mii.equality_columns = mi.equality_columns collate database_default
			and mii.statement = mi.statement collate database_default

		-- this is not required as in this case we not populating [dbo].[sqlwatch_meta_index_missing] at all to reduce noise
		--left join [dbo].[sqlwatch_config_logger_exclude_database] ed
		--	on db.[database_name] like ed.database_name_pattern
		--	and ed.snapshot_type_id = @snapshot_type_id

	where mi.equality_columns is not null
	and mi.statement is not null

commit tran


