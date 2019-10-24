-- =============================================
-- Author: Colin Douglas
-- Create date: 09/20/2018
-- Description: Captures Missing Indexes
--
-- Changes:
--		Marcin Gminski 22/09/2018:
--			1. If we remove table_name from the [create_tsql]
--				we will also be able to remove sc.[name], so.[name]
--				from the cursor.
--			2. as we no longer need to join on:
--					   JOIN ' + QUOTENAME(@database_name) + N'.sys.objects so on 
--						  id.object_id=so.object_id
--					   JOIN ' + QUOTENAME(@database_name) + N'.sys.schemas sc on 
--						  so.schema_id=sc.schema_id
--				we can remove the cursor entirely. This will improve the execution
--				time on servers with large number of dbs and simplify the code.
--			3. as we no longer need a cursor, we also do not need #database_list
--			4. for the sake of simplicity, we also do not need #missing_indexes,
--				we can insert directly into the target table
--			5. even though I originally suggested it, I am going to remove
--				column [benefit] as it is a simple calculation based on
--				existing columns which can be done during reporting (PowerBI)
--			6. the final table [dbo].[logger_missing_indexes] does not have
--				some of the useful columns that #missing_indexes had so I am 
--				going to bring them in
--			7. the CREATE INDEX statement has ONLINE=? which only works in
--				the Enterprise edition so I am going to add a check for it
--			8. the CREATE INDEX contains table name and column lists in the name
--				I am not against it but something it can create long names.
--				as I have removed table_name for the sake of simplicity
--				I am happy to make a compromise and remove table and column list
--				entirely but add index_id, timestamp and "SQLWATCH" into the name
--				so we know where the index has come from and when.
--			9. I am also going to modify table [dbo].[logger_missing_indexes]
--				and remove [snapshot_type_id] TINYINT NULL DEFAULT 1 and
--				give it its own snapshot_id with its own retention and schedule
--			10. I am going to create necessary PKs and FKs
--			11. I am going to rename @date_snapshot_current to @snapshot_type to
--				make it consistent with other procedures. The snapshot _current and
--				_previous only apply to cumulative snapshots where we calculate
--				deltas.
--			12. I am going to change CAST(avg_user_impact as nvarchar) + '%' [Impact]
--				to simply avg_user_impact as it is much more efficient to store raw
--				numerical value in the databases and format in the presentation tier.
--			13. I am going to add servername in preparation for the future central repo.
--			14. I am also goint to NOT exclude SQLWATCH from the database list because why 
--				would we not capture missing indexes in SQLWATCH :)
--			15. I am going to remove FILLFACTOR=100 as this is the default anyway. 
--				Some DBAs may have different preference and different default FILLFACTOR 
--				and I wouldnt want to force any config different to what they prefer.
-- =============================================
CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_missing_index_stats]
AS
set xact_abort on
begin tran

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    
	--------------------------------------------------------------------------------------------------------------
    -- variables
	--------------------------------------------------------------------------------------------------------------
	declare @snapshot_time datetime = getutcdate();
	declare @snapshot_type tinyint = 3
	insert into [dbo].[sqlwatch_logger_snapshot_header] (snapshot_time, snapshot_type_id)
	values (@snapshot_time, @snapshot_type)

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
		[snapshot_type_id] = @snapshot_type,
		@@SERVERNAME
	from sys.dm_db_missing_index_groups ig 

		inner join sys.dm_db_missing_index_group_stats igs 
			on igs.group_handle = ig.index_group_handle 

		inner join sys.dm_db_missing_index_details mi 
			on ig.index_handle = mi.index_handle

		inner join sys.databases sdb
			on sdb.[name] = db_name(mi.[database_id])
			and sdb.database_id > 4
			and sdb.[name] not like '%ReportServer%'

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

	where mi.equality_columns is not null
	and mi.statement is not null

commit tran


