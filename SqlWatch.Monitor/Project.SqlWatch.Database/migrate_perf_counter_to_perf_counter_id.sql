create table [dbo].[sqlwatch_meta_performance_counter]
(
	[sql_instance] varchar(32) not null,
	[object_name] nvarchar(128) not null,
	[counter_name] nvarchar(128) not null,
	[cntr_type] int not null,
	[performance_counter_id] smallint identity (-32768,1) not null,
	constraint pk_sqlwatch_meta_performance_counter primary key (
		[sql_instance], [performance_counter_id]
		),
	constraint uq_sqlwatch_meta_performance_counter_object unique ([sql_instance], [object_name], [counter_name])
)


  insert into [dbo].[sqlwatch_meta_performance_counter] ([sql_instance],[object_name],[counter_name],[cntr_type])
  select distinct @@SERVERNAME, rtrim(pc.[object_name]), rtrim(pc.[counter_name]), pc.[cntr_type]
  from sys.dm_os_performance_counters pc
  left join [dbo].[sqlwatch_meta_performance_counter] mc
	on rtrim(pc.[object_name]) = mc.[object_name] collate database_default
	and rtrim(pc.[counter_name]) = mc.[counter_name] collate database_default
	and mc.[sql_instance] = @@SERVERNAME
  where mc.counter_name is null

  insert into [dbo].[sqlwatch_meta_performance_counter] ([sql_instance],[object_name],[counter_name],[cntr_type])
  values ( @@SERVERNAME, 'win32_perfformatteddata_perfos_processor','Processor Time %', 65792 )

  drop table #sqlwatch_logger_perf_os_performance_counters
  select pc.*, mc.performance_counter_id
  into #sqlwatch_logger_perf_os_performance_counters
  from [dbo].[sqlwatch_logger_perf_os_performance_counters] pc
	left join [dbo].[sqlwatch_meta_performance_counter] mc
		on pc.sql_instance = mc.sql_instance
		and pc.object_name = mc.object_name
		and pc.counter_name = mc.counter_name

  set xact_abort on;

  begin transaction fred

  delete from [dbo].[sqlwatch_logger_perf_os_performance_counters]

  insert into [dbo].[sqlwatch_logger_perf_os_performance_counters] (object_name, instance_name, counter_name, cntr_value, base_cntr_value, cntr_type, snapshot_time, snapshot_type_id, sql_instance)
  select object_name= performance_counter_id, instance_name, counter_name, cntr_value, base_cntr_value, cntr_type, snapshot_time, snapshot_type_id, sql_instance
  from #sqlwatch_logger_perf_os_performance_counters

  --commit transaction fred

  alter table [dbo].[sqlwatch_logger_perf_os_performance_counters] drop column counter_name
  alter table [dbo].[sqlwatch_logger_perf_os_performance_counters] drop column cntr_type

  alter table [dbo].[sqlwatch_logger_perf_os_performance_counters] alter column object_name smallint not null
  select * from [dbo].[sqlwatch_logger_perf_os_performance_counters]

--231,314

--commit tran fred