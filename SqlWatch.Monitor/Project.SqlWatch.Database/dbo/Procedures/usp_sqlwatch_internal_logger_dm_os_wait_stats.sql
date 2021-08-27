CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_dm_os_wait_stats]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32),
	@snapshot_time_previous datetime2(0)
AS
begin
	set nocount on;

	declare @xml_parser_os_wait_stats as [dbo].[utype_sqlwatch_sys_dm_os_wait_stats];

	insert into @xml_parser_os_wait_stats (
			 wait_type 
			,waiting_tasks_count 
			,wait_time_ms 
			,max_wait_time_ms 
			,signal_wait_time_ms 
			,snapshot_time 
			,snapshot_type_id
			,sql_instance 
	)
	select
		wait_type 
		,waiting_tasks_count 
		,wait_time_ms 
		,max_wait_time_ms 
		,signal_wait_time_ms 
		,snapshot_time = @snapshot_time
		,snapshot_type_id = @snapshot_type_id
		,sql_instance = @sql_instance
	from openxml (@xdoc, '/CollectionSnapshot/dm_os_wait_stats/row',1) 
	with (
		[wait_type] nvarchar(60),
		[waiting_tasks_count] bigint,
		[wait_time_ms] bigint,
		[max_wait_time_ms] bigint,
		[signal_wait_time_ms] bigint
	)
	option (maxdop 1, keep plan);

	with cte_calc as (
		select 
			  [wait_type_id] = ms.[wait_type_id]
			, [waiting_tasks_count] = convert(real,ws.[waiting_tasks_count])
			, [wait_time_ms] = convert(real,ws.[wait_time_ms])
			, [max_wait_time_ms] = convert(real,ws.[max_wait_time_ms])
			, [signal_wait_time_ms] = convert(real,ws.[signal_wait_time_ms])
				
			, ws.snapshot_time
			, ws.snapshot_type_id
			, ws.sql_instance

			, [waiting_tasks_count_delta] = convert(real,case when ws.[waiting_tasks_count] > wsprev.[waiting_tasks_count] then ws.[waiting_tasks_count] - wsprev.[waiting_tasks_count] else 0 end)
			, [wait_time_ms_delta] = convert(real,case when ws.[wait_time_ms] > wsprev.[wait_time_ms] then ws.[wait_time_ms] - wsprev.[wait_time_ms] else 0 end)
			, [max_wait_time_ms_delta] = convert(real,case when ws.[max_wait_time_ms] > wsprev.[max_wait_time_ms] then ws.[max_wait_time_ms] - wsprev.[max_wait_time_ms] else 0 end)
			, [signal_wait_time_ms_delta] = convert(real,case when ws.[signal_wait_time_ms] > wsprev.[signal_wait_time_ms] then ws.[signal_wait_time_ms] - wsprev.[signal_wait_time_ms] else 0 end)
			, [delta_seconds] = datediff(second,wsprev.snapshot_time,ws.snapshot_time)
		from @xml_parser_os_wait_stats ws

		inner join [dbo].[sqlwatch_meta_dm_os_wait_stats] ms
			on ms.[wait_type] = ws.[wait_type] collate database_default
			and ms.[sql_instance] = ws.sql_instance
			and ms.is_excluded = 0

		left join [dbo].[sqlwatch_stage_perf_os_wait_stats] wsprev
			on wsprev.wait_type = ws.wait_type
			and wsprev.snapshot_time = @snapshot_time_previous
			and wsprev.sql_instance = ws.sql_instance

		where ws.[waiting_tasks_count] - wsprev.[waiting_tasks_count]  > 0
	)
	insert into [dbo].[sqlwatch_logger_dm_os_wait_stats]
	select 
		[wait_type_id]
		, [waiting_tasks_count]
		, [wait_time_ms]
		, [max_wait_time_ms]
		, [signal_wait_time_ms]
		, [snapshot_time]
		, [snapshot_type_id]
		, [sql_instance]
		, [waiting_tasks_count_delta]
		, [wait_time_ms_delta]
		, [max_wait_time_ms_delta]
		, [signal_wait_time_ms_delta]
		, [delta_seconds]
		-- In the given snapshot, how much time was spent on each wait from across all waits in the snapshot
		-- this used to be real data type but essentially we just want to know the percentage of time spent across the sample
		-- and since percentage can be 0-100, tinyint will be more than enough and 3 times smaller than real
		, [percent_time_wait] = case when  sum ([wait_time_ms_delta]) OVER() > 0 then convert(tinyint, [wait_time_ms_delta] * 100.00 / sum ([wait_time_ms_delta]) OVER()) else 0 end
	from cte_calc


	option (keepfixed plan);

	delete from [dbo].[sqlwatch_stage_perf_os_wait_stats]
	where sql_instance = @sql_instance
	option (keep plan);

	insert into [dbo].[sqlwatch_stage_perf_os_wait_stats] (
		 [wait_type] 
		,[waiting_tasks_count] 
		,[wait_time_ms] 
		,[max_wait_time_ms] 
		,[signal_wait_time_ms] 
		,snapshot_time
		,wait_type_id 
		,sql_instance 
	)
	select 
		  [ws].[wait_type]
		, [ws].[waiting_tasks_count]
		, [ws].[wait_time_ms]
		, [ws].[max_wait_time_ms]
		, [ws].[signal_wait_time_ms]
		, ws.snapshot_time
		, ms.wait_type_id
		, [ws].[sql_instance] 
	from @xml_parser_os_wait_stats ws

	inner join [dbo].[sqlwatch_meta_dm_os_wait_stats] ms
		on ms.[wait_type] = ws.[wait_type] collate database_default
		and ms.[sql_instance] = ws.sql_instance

	option (keep plan);
end;
