CREATE VIEW [dbo].[vw_sql_perf_mon_rep_perf_counter] AS
			select distinct
				 [report_name] = 'Performance Counters'
				,[report_time] = s.snapshot_interval_end
				,[object_name] = rtrim(ltrim(pc.[object_name]))
				,[instance_name] = rtrim(ltrim(isnull(pc.instance_name, '')))
				,counter_name = rtrim(ltrim(pc.counter_name))
				,[cntr_value] = convert(real,(
					case 
						when sc.object_name = 'Batch Resp Statistics' then case when pc.cntr_value > fsc.cntr_value then cast((pc.cntr_value - fsc.cntr_value) as real) else 0 end -- delta absolute
						when pc.cntr_type = 65792 then isnull(pc.cntr_value,0) -- point-in-time
						when pc.cntr_type = 272696576 then case when (pc.cntr_value > fsc.cntr_value) then (pc.cntr_value - fsc.cntr_value) / cast(datediff(second,s.first_snapshot_time,s.last_snapshot_time) as real) else 0 end -- delta rate
						when pc.cntr_type = 537003264 then isnull(cast(100.0 as real) * pc.cntr_value / nullif(bc.cntr_value, 0),0) -- ratio
						when pc.cntr_type = 1073874176 then isnull(case when pc.cntr_value > fsc.cntr_value then isnull((pc.cntr_value - fsc.cntr_value) / nullif(bc.cntr_value - fsc.base_cntr_value, 0) / cast(datediff(second,s.first_snapshot_time,s.last_snapshot_time) as real), 0) else 0 end,0) -- delta ratio
						end))
				,s.[report_time_interval_minutes]
		from dbo.sql_perf_mon_perf_counters as pc
		inner join [dbo].[vw_sql_perf_mon_time_intervals] s
			on pc.snapshot_time = s.last_snapshot_time 

		inner join dbo.[sqlwatch_config_performance_counters] as sc
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
						from [dbo].[sql_perf_mon_perf_counters] 
						where snapshot_time = s.first_snapshot_time
						) as fsc
					where fsc.[object_name] = rtrim(pc.[object_name])
							and fsc.counter_name = rtrim(pc.counter_name)
							and fsc.instance_name = rtrim(pc.instance_name)
					) as fsc
		outer apply (
					select top (1) pc2.cntr_value
					from [dbo].[sql_perf_mon_perf_counters] as pc2 
					where snapshot_time = s.last_snapshot_time 
						and pc2.cntr_type = 1073939712
							and pc2.object_name = pc.object_name
							and pc2.instance_name = pc.instance_name
							and rtrim(pc2.counter_name) = sc.base_counter_name
					) as bc
		where -- exclude base counters
				pc.cntr_type in (65792,272696576,537003264,1073874176)
go