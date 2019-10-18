CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_performance_counter]
as

  insert into [dbo].[sqlwatch_meta_performance_counter] ([sql_instance],[object_name],[counter_name],[cntr_type])
  select distinct @@SERVERNAME, rtrim(pc.[object_name]), rtrim(pc.[counter_name]), pc.[cntr_type]
  from sys.dm_os_performance_counters pc
  left join [dbo].[sqlwatch_meta_performance_counter] mc
	on rtrim(pc.[object_name]) = mc.[object_name] collate database_default
	and rtrim(pc.[counter_name]) = mc.[counter_name] collate database_default
	and mc.[sql_instance] = @@SERVERNAME
  where mc.counter_name is null

  insert into [dbo].[sqlwatch_meta_performance_counter] ([sql_instance],[object_name],[counter_name],[cntr_type])
  select pc.[sql_instance],pc.[object_name],pc.[counter_name],pc.[cntr_type]
  from (
	select [sql_instance] = @@SERVERNAME, [object_name] = 'win32_perfformatteddata_perfos_processor', [counter_name] = 'Processor Time %', [cntr_type] = 65792
	) pc
  left join [dbo].[sqlwatch_meta_performance_counter] mc
	on rtrim(pc.[object_name]) = mc.[object_name] collate database_default
	and rtrim(pc.[counter_name]) = mc.[counter_name] collate database_default
	and mc.[sql_instance] = @@SERVERNAME
  where mc.counter_name is null