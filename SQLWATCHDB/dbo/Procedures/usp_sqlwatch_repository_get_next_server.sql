CREATE PROCEDURE [dbo].[usp_sqlwatch_repository_get_next_server] (
	@sql_instance varchar(32) output
	)
AS

	--set xact_abort on;
	--set nocount on;

	--declare @output as table (
	--	sql_instance varchar(32)
	--)

	--set @sql_instance = null

	--begin transaction
	--	;with cte_next_server as (

	--			select top 1 sql_instance , [repo_last_collection_status], [repo_last_collection_start_time]
	--			from [dbo].[sqlwatch_config_sql_instance]
	--			where [repo_collector_is_active] = 1
	--			and (
	--					[repo_last_collection_status] not in ( 'Running', 'ERROR' )
	--				 or [repo_last_collection_status] is null
					 
	--				 /* re-try any failed collections that have failed over 1 hour ago */
	--				 or (
	--						[repo_last_collection_status] = 'ERROR'
	--					and [repo_last_collection_finish_time] < dateadd(minute,-60,getutcdate())
	--					)

	--				 /*	re-set any running collectors that have been runnig for over 1 hour 
	--					as they are likely orphaned workers */
	--				 or (
	--						[repo_last_collection_status] = 'Running'
	--					and [repo_last_collection_start_time] < dateadd(minute,-60,getutcdate())
	--					)
	--				)

	--			/* do not collect own instance */
	--			and sql_instance <> @@servername
	--			)
	--		update cte_next_server
	--			set [repo_last_collection_status] = 'Running'
	--				, [repo_last_collection_start_time] = sysutcdatetime()
	--		output inserted.sql_instance into @output
	--commit transaction

	--		select @sql_instance = nullif(sql_instance,'')
	--		from @output


	SELECT CONVERT(INT,'am I used?')
return
