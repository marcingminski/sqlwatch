CREATE PROCEDURE [dbo].[usp_sqlwatch_report_get_performance_counters]
(
	@interval_minutes smallint = null,
	@report_window int = null,
	@report_end_time datetime = null,
	@sql_instance nvarchar(25) = null
	)
as

if @report_end_time  is null
set @report_end_time = GETUTCDATE()

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
--get performance counters we are interested in:
select pc.performance_counter_id
	, pc.base_cntr_value
	, pc.cntr_value
	, pc.instance_name
	, pc.snapshot_time
	, pc.snapshot_type_id
	, mc.object_name
	, mc.counter_name
	, mc.cntr_type
	, pc.sql_instance
	, mdb.sqlwatch_database_id
into #perf_counters_filtered
from [sqlwatch_logger_perf_os_performance_counters] as pc

inner join [dbo].[sqlwatch_meta_performance_counter] mc
	on mc.sql_instance = pc.sql_instance
	and mc.performance_counter_id = pc.performance_counter_id

left join [dbo].[sqlwatch_meta_database] mdb
	on mdb.sql_instance = pc.sql_instance
	and mdb.[database_name] = pc.instance_name
	and mdb.database_create_date <= pc.snapshot_time

where pc.sql_instance = isnull(@sql_instance,pc.sql_instance)
	and	pc.[snapshot_time] >= (select min(first_snapshot_time) from [dbo].[ufn_sqlwatch_time_intervals](1,@interval_minutes,@report_window,@report_end_time))
	and pc.[snapshot_time] <= @report_end_time

	select /* SQLWATCH Power BI fn_get_performance_counters */ distinct
		 pc.[sql_instance]
		,pc.snapshot_type_id
		,[report_time] = snapshot_interval_end
		,[object_name] = rtrim(ltrim(pc.[object_name]))
		,[instance_name] = case when rtrim(ltrim(pc.[object_name])) = 'win32_perfformatteddata_perfos_processor' and rtrim(ltrim(pc.counter_name)) = 'Processor Time %' and rtrim(ltrim(isnull(pc.instance_name,'')))
 = 'system' then 'os' else rtrim(ltrim(pc.instance_name)) end
		,counter_name = rtrim(ltrim(pc.counter_name))
		,[cntr_value] = convert(real,(
			case 
				when sc.object_name = 'Batch Resp Statistics' then case when pc.cntr_value > fsc.cntr_value then cast((pc.cntr_value - fsc.cntr_value) as real) else 0 end -- delta absolute
				when pc.cntr_type = 65792 then isnull(pc.cntr_value,0) -- point-in-time
				when pc.cntr_type = 272696576 then case when (pc.cntr_value > fsc.cntr_value) then (pc.cntr_value - fsc.cntr_value) / cast(datediff(second,first_snapshot_time,last_snapshot_time) as real) else 0 end -- delta rate
				when pc.cntr_type = 537003264 then isnull(cast(100.0 as real) * pc.cntr_value / nullif(bc.cntr_value, 0),0) -- ratio
				when pc.cntr_type = 1073874176 then isnull(case when pc.cntr_value > fsc.cntr_value then isnull((pc.cntr_value - fsc.cntr_value) / nullif(bc.cntr_value - fsc.base_cntr_value, 0) / cast(datediff(second,first_snapshot_time,last_snapshot_time) as real), 0) else 0 end,0) -- delta ratio
			end))
		 ,sqlwatch_database_id
from #perf_counters_filtered as pc

inner join [dbo].[ufn_sqlwatch_time_intervals](1,@interval_minutes,@report_window,@report_end_time) s
	on pc.snapshot_time = s.last_snapshot_time 
        and s.snapshot_type_id = pc.snapshot_type_id
		and s.sql_instance = pc.sql_instance

inner join [dbo].[sqlwatch_config_performance_counters] as sc
on rtrim(pc.object_name) like '%' + sc.object_name
	and rtrim(pc.counter_name) = sc.counter_name
	and (rtrim(pc.instance_name) = sc.instance_name 
		or (
			sc.instance_name = '<* !_total>' 
			and rtrim(pc.instance_name) <> '_total'
			)
	)
outer apply (
			select top (1) fsc.cntr_value,
							fsc.base_cntr_value
			from (
				select * 
				from #perf_counters_filtered 
				where snapshot_time = first_snapshot_time
				and sql_instance = sql_instance
				) as fsc
			where fsc.[object_name] = rtrim(pc.[object_name])
					and fsc.counter_name = rtrim(pc.counter_name)
					and fsc.instance_name = rtrim(pc.instance_name)
					and fsc.sql_instance = pc.sql_instance
			) as fsc
outer apply (
			select top (1) pc2.cntr_value
			from #perf_counters_filtered as pc2 
			where snapshot_time = last_snapshot_time 
				and pc2.cntr_type = 1073939712
					and pc2.object_name = pc.object_name
					and pc2.instance_name = pc.instance_name
					and rtrim(pc2.counter_name) = sc.base_counter_name
					and pc2.sql_instance = pc.sql_instance
			) as bc

where 		pc.cntr_type in (272696576,1073874176)
and pc.sql_instance = isnull(@sql_instance,pc.sql_instance)

union all

-- point in time and ratio counters that must be averaged over period of time
select 
     pc.sql_instance
	,s.snapshot_type_id
	,report_time = s.snapshot_interval_end
    ,[object_name] = rtrim(ltrim(pc.[object_name]))
    ,[instance_name] = case when rtrim(ltrim(pc.[object_name])) = 'win32_perfformatteddata_perfos_processor' and rtrim(ltrim(pc.counter_name)) = 'Processor Time %' and rtrim(ltrim(isnull(pc.instance_name, ''))) = 'system' then 'os' 
            else rtrim(ltrim(pc.instance_name)) end
    , [counter_name] = rtrim(ltrim(pc.counter_name))
	, [cntr_value] = avg(convert(real,(case 
		when pc.cntr_type = 65792 then isnull(pc.cntr_value,0) -- point-in-time
		when pc.cntr_type = 537003264 then isnull(cast(100.0 as real) * pc.cntr_value / nullif(bc.cntr_value, 0),0) -- ratio
		end)))
	,pc.sqlwatch_database_id
from #perf_counters_filtered pc

INNER JOIN [dbo].[ufn_sqlwatch_time_intervals](1,@interval_minutes,@report_window,@report_end_time) s
	on pc.snapshot_time = s.last_snapshot_time 
	and s.snapshot_type_id = pc.snapshot_type_id
	and s.sql_instance = pc.sql_instance

inner join [dbo].[sqlwatch_config_performance_counters] as sc
	on rtrim(pc.object_name) like '%' + sc.object_name
	and rtrim(pc.counter_name) = sc.counter_name
	and (rtrim(pc.instance_name) = sc.instance_name 
		or (
			sc.instance_name = '<* !_total>' 
			and rtrim(pc.instance_name) <> '_total'
			)
	)
outer apply (
			select top (1) pc2.cntr_value
			from #perf_counters_filtered as pc2 
			where snapshot_time = s.last_snapshot_time 
				and pc2.cntr_type = 1073939712
					and pc2.object_name = pc.object_name
					and pc2.instance_name = pc.instance_name
					and rtrim(pc2.counter_name) = sc.base_counter_name
			) as bc
    where pc.snapshot_time between s.first_snapshot_time and s.last_snapshot_time
	and pc.sql_instance = isnull(@sql_instance,pc.sql_instance)
    and pc.cntr_type in (65792,537003264)
	group by s.snapshot_type_id, pc.sql_instance, s.snapshot_interval_end, rtrim(ltrim(pc.[object_name])), 
	case when rtrim(ltrim(pc.[object_name])) = 'win32_perfformatteddata_perfos_processor' and rtrim(ltrim(pc.counter_name)) = 'Processor Time %' and rtrim(ltrim(isnull(pc.instance_name, ''))) = 'system' then 'os' 
            else rtrim(ltrim(pc.instance_name)) end,
			rtrim(ltrim(pc.counter_name)), sqlwatch_database_id
