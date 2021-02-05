CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_performance_counter]
as


;merge [dbo].[sqlwatch_meta_performance_counter] as target
using (
		select distinct 
			[sql_instance] = @@SERVERNAME
			, [object_name] = rtrim(pc.[object_name])
			, [counter_name] = rtrim(pc.[counter_name])
			, [cntr_type] = pc.[cntr_type]
		from sys.dm_os_performance_counters pc
		union all
		select 
			[sql_instance] = @@SERVERNAME
			, [object_name] = 'Win32_PerfFormattedData_PerfOS_Processor'
			, [counter_name] = 'Processor Time %'
			, [cntr_type] = 65792
		) as source
	on target.sql_instance = source.sql_instance collate database_default
	and target.object_name = source.object_name collate database_default
	and target.counter_name = source.counter_name collate database_default

--when matched then
--	update set date_last_seen = getutcdate()

when not matched then
	insert ([sql_instance],[object_name],[counter_name],[cntr_type])
	values (source.[sql_instance],source.[object_name],source.[counter_name],source.[cntr_type]);
