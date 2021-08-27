CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_dm_os_performance_counters]
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32),
	@xdoc int,
	@snapshot_time_previous datetime2(0)
as
begin
	set nocount on;

	insert into dbo.[sqlwatch_logger_dm_os_performance_counters] (
		  [performance_counter_id]
		, [instance_name]
		, [cntr_value]
		, [base_cntr_value]
		, [snapshot_time]
		, [snapshot_type_id]
		, [sql_instance]
		, [cntr_value_calculated]
		)

	select
		  mc.[performance_counter_id]
		, instance_name = rtrim(pc.instance_name)
		, pc.cntr_value
		, base_cntr_value = pc.base_cntr_value
		, @snapshot_time
		, @snapshot_type_id
		, @sql_instance
		,[cntr_value_calculated] = convert(real,(
			case 
				--https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.performancecountertype?view=netframework-4.8
				--https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.performancedata.countertype?view=netframework-4.8
				when pc.object_name = 'Batch Resp Statistics' then case when pc.cntr_value > prev.cntr_value then cast((pc.cntr_value - prev.cntr_value) as real) else 0 end -- delta absolute
					
				/*	65792
					An instantaneous counter that shows the most recently observed value. Used, for example, to maintain a simple count of a very large number of items or operations. 
					It is the same as NumberOfItems32 except that it uses larger fields to accommodate larger values.	*/
				when pc.cntr_type = 65792 then isnull(pc.cntr_value,0) 	
					
				/*	272696576
					A difference counter that shows the average number of operations completed during each second of the sample interval. Counters of this type measure time in ticks of the system clock. 
					This counter type is the same as the RateOfCountsPerSecond32 type, but it uses larger fields to accommodate larger values to track a high-volume number of items or operations per second, 
					such as a byte-transmission rate. Counters of this type include System\ File Read Bytes/sec.	*/
				when pc.cntr_type = 272696576 then case when (pc.cntr_value > prev.cntr_value) then (pc.cntr_value - prev.cntr_value) / cast(datediff(second,prev.snapshot_time,@snapshot_time) as real) else 0 end -- delta rate
					
				/*	537003264	
					This counter type shows the ratio of a subset to its set as a percentage. For example, it compares the number of bytes in use on a disk to the total number of bytes on the disk. 
					Counters of this type display the current percentage only, not an average over time. It is the same as the RawFraction32 counter type, except that it uses larger fields to accommodate larger values.	*/
				when pc.cntr_type = 537003264 then isnull(cast(100.0 as real) * pc.cntr_value / nullif(pc.base_cntr_value, 0),0) -- ratio

				/*	1073874176		
					An average counter that shows how many items are processed, on average, during an operation. Counters of this type display a ratio of the items processed to the number of operations completed. 
					The ratio is calculated by comparing the number of items processed during the last interval to the number of operations completed during the last interval. 
					Counters of this type include PhysicalDisk\ Avg. Disk Bytes/Transfer.	*/
				when pc.cntr_type = 1073874176 then isnull(case when pc.cntr_value > prev.cntr_value then isnull((pc.cntr_value - prev.cntr_value) / nullif(pc.base_cntr_value - prev.base_cntr_value, 0) / cast(datediff(second,prev.snapshot_time,@snapshot_time) as real), 0) else 0 end,0) -- delta ratio

				--any other not in the will need to be pre-calculated, for example from CLR, such as CPU %.
				else pc.cntr_value
			end))
	from openxml (@xdoc, '/CollectionSnapshot/dm_os_performance_counters/row',1) 
	with (
		[object_name] nvarchar(128)
		,[counter_name] nvarchar(128)
		,[instance_name] nvarchar(128)
		,cntr_value real
		,cntr_type int
		,base_counter_name nvarchar(128)
		,base_cntr_value real
	) pc

	inner join [dbo].[sqlwatch_meta_dm_os_performance_counters] mc (nolock)
		on mc.[object_name] = pc.[object_name] collate database_default
		and mc.[counter_name] = pc.[counter_name] collate database_default
		and mc.[sql_instance] = @sql_instance 

	left join [dbo].[sqlwatch_logger_dm_os_performance_counters] prev (nolock) --previous
		on prev.snapshot_time = @snapshot_time_previous
		and prev.performance_counter_id = mc.performance_counter_id
		and prev.instance_name = pc.instance_name collate database_default
		and prev.sql_instance = @sql_instance 
		and prev.snapshot_type_id = @snapshot_type_id
		
	option (maxdop 1, keep plan);
end;
