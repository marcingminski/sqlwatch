CREATE PROCEDURE [dbo].[usp_sqlwatch_report_get_missing_index]
(
	@interval_minutes smallint = null,
	@report_window int = null,
	@report_end_time datetime = null,
	@sql_instance nvarchar(25) = null
	)
as

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

if @report_window is null
set @report_window = 4

if @report_end_time is null
set @report_end_time= getutcdate()

select 
	@interval_minutes  = case when @interval_minutes  is null then report_time_interval_minutes else @interval_minutes end
from [dbo].[ufn_sqlwatch_time_intervals](1,@interval_minutes,@report_window,@report_end_time)



	--only enterprise and developer will allow online index build/rebuild
	declare @allows_online_index bit
	select @allows_online_index = case 
			when
					convert(varchar(4000),serverproperty('Edition')) like 'Enterprise%' 
				or	convert(varchar(4000),serverproperty('Edition')) like 'Developer%'
			then 1
			else 0
		end

 select /* SQLWATCH Power BI fn_get_missing_indexes */
      --,mi.[database_name]
      --,mi.[database_create_date]
       --mi.[sqlwatch_database_id]
	   mi.sqlwatch_database_id,
	   mi.sqlwatch_table_id
      ,[report_time] = mi.snapshot_time
      ,[index_handle]
      ,[last_user_seek]
      ,[unique_compiles]
      ,[user_seeks]
      ,[user_scans]
      ,[avg_total_user_cost]
      ,[avg_user_impact]
      ,[missing_index_def] = 'CREATE INDEX SQLWATCH_AUTOIDX_' + rtrim(convert(char(100),im.[index_handle])) + 
			'_' + convert(varchar(10),getutcdate(),112) + ' ON ' + im.statement + ' (' + 
			case when [equality_columns] is not null then [equality_columns] else '' end + 
			case when [equality_columns] is not null and [inequality_columns] is not null then ', ' else '' end + 
			case when [inequality_columns] is not null then [inequality_columns] else '' end + ') ' + 
			case when [included_columns] is not null then 'INCLUDE (' + [included_columns] + ')' else '' end
			+ N' WITH (' 
				+ case when @allows_online_index = 1 then N'ONLINE=ON,' else N'' end + N'SORT_IN_TEMPDB=ON' 
			+ N')',
      mi.sql_instance
      ,mi.snapshot_type_id
  FROM [dbo].[sqlwatch_logger_index_missing_stats] mi

	inner join [dbo].[sqlwatch_meta_index_missing] im
		on im.sql_instance = mi.sql_instance
		and im.[sqlwatch_database_id] = mi.[sqlwatch_database_id]
		and im.[sqlwatch_table_id] = mi.[sqlwatch_table_id]
		and im.[sqlwatch_missing_index_id] = mi.[sqlwatch_missing_index_id]




where
		mi.[snapshot_time] >= DATEADD(DAY, -@report_window, @report_end_time)
	and mi.[snapshot_time] <= @report_end_time
	and mi.sql_instance = isnull(@sql_instance,mi.sql_instance)