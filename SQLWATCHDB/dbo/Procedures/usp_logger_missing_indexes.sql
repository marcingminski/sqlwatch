-- =============================================
-- Author: Colin Douglas
-- Create date: 09/20/2018
-- Description: Captures Missing Indexes
-- =============================================
CREATE PROCEDURE [dbo].[usp_logger_missing_indexes]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    
    /* Variables */
    declare @sql nvarchar(max);
    declare @database_id int;
    declare @database_name nvarchar(128);
    declare @date_snapshot_current datetime = GETDATE()

    /* Temp Tables */
    create table #database_list (
	    database_name NVARCHAR(256)
    )

    create table #missing_indexes
	   (
		  [database_name] nvarchar(128) not null,
		  [schema_name] nvarchar(128) not null,
		  [table_name] nvarchar(128),
		  [statement] nvarchar(512) not null,
		  [benefit] as (( user_seeks + user_scans ) * avg_total_user_cost * (avg_user_impact * .01)),
		  [avg_total_user_cost] numeric(29,4) not null,
		  [avg_user_impact] numeric(29,1) not null,
		  [user_seeks] bigint not null,
		  [user_scans] bigint not null,
		  [last_user_seek] datetime null,
		  [last_user_scan] datetime null,
		  [unique_compiles] bigint null,
		  [equality_columns] nvarchar(4000), 
		  [inequality_columns] nvarchar(4000),
		  [included_columns] nvarchar(4000),
		  [create_tsql] AS N'CREATE INDEX [ix_' + table_name + N'_' 
				    + REPLACE(REPLACE(REPLACE(REPLACE(
					   ISNULL(equality_columns,N'')+ 
					   CASE WHEN equality_columns IS NOT NULL AND inequality_columns IS NOT NULL THEN N'_' ELSE N'' END
					   + ISNULL(inequality_columns,''),',','')
					   ,'[',''),']',''),' ','_') 
				    + CASE WHEN included_columns IS NOT NULL THEN N'_includes' ELSE N'' END + N'] ON ' 
				    + [statement] + N' (' + ISNULL(equality_columns,N'')
				    + CASE WHEN equality_columns IS NOT NULL AND inequality_columns IS NOT NULL THEN N', ' ELSE N'' END
				    + CASE WHEN inequality_columns IS NOT NULL THEN inequality_columns ELSE N'' END + 
				    ') ' + CASE WHEN included_columns IS NOT NULL THEN N' INCLUDE (' + included_columns + N')' ELSE N'' END
				    + N' WITH (' 
					   + N'FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?' 
				    + N')'
				    + N';'
	   )


    insert into #database_list (database_name)
    select  DB_NAME(database_id)
    from	   sys.databases
    where   user_access_desc='MULTI_USER'
		  and state_desc = 'ONLINE'
		  and database_id > 4
		  and is_distributor = 0
		  and DB_NAME(database_id) NOT LIKE 'ReportServer%'
		  and DB_NAME(database_id) <> 'SQLWATCH';


    declare c1 cursor
    local fast_forward 
    for 
    select database_name 
    from #database_list 
    order by database_name

    open c1
    fetch next from c1 into @database_name

    while @@FETCH_STATUS = 0
    begin
   
	   select  @database_id = [database_id]
	   from	  sys.databases
	   where	  [name] = @database_name

	   set @sql=N'SELECT  ' + QUOTENAME(@database_name,'''') + N', sc.[name], so.[name], id.statement , gs.avg_total_user_cost, 
					   gs.avg_user_impact, gs.user_seeks, gs.user_scans, gs.last_user_seek, gs.last_user_scan, gs.unique_compiles,id.equality_columns, 
					   id.inequality_columns,id.included_columns
				FROM    sys.dm_db_missing_index_groups ig
					   JOIN sys.dm_db_missing_index_details id ON ig.index_handle = id.index_handle
					   JOIN sys.dm_db_missing_index_group_stats gs ON ig.index_group_handle = gs.group_handle
					   JOIN ' + QUOTENAME(@database_name) + N'.sys.objects so on 
						  id.object_id=so.object_id
					   JOIN ' + QUOTENAME(@database_name) + N'.sys.schemas sc on 
						  so.schema_id=sc.schema_id
				WHERE    id.database_id = ' + CAST(@database_id AS NVARCHAR(30)) +
				N'OPTION (RECOMPILE);'

        
	   insert  #missing_indexes (  [database_name], [schema_name], [table_name], [statement], [avg_total_user_cost], 
							 [avg_user_impact], [user_seeks], [user_scans], [last_user_seek], [last_user_scan], [unique_compiles], [equality_columns], 
							 [inequality_columns], [included_columns])
	   exec sp_executesql @sql;

	   fetch next from c1 into @database_name

    end
                        

    insert into [dbo].[logger_missing_indexes]
    select 
		  @date_snapshot_current [Snapshot Time],
		  database_name [Database Name],
		  mi.statement [Statement],
		  mi.benefit [Benefit],
		  equality_columns [Equality Columns],
		  inequality_columns [Inequality Columns],
		  included_columns [Included Columns],
		  (user_seeks + user_scans) [Usage],
		  CAST(avg_user_impact as nvarchar) + '%' [Impact],
		  avg_total_user_cost [Average Query Cost],
		  last_user_seek [Last User Seek],
		  last_user_scan [Last User Scan],
		  unique_compiles [Unique Compiles],
		  create_tsql [Create TSQL]
    from    #missing_indexes mi
    order by benefit desc


END

GO


