CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_performance_counter]
as

create table #t (
	[sql_instance] varchar(32) not null,
	[object_name] nvarchar(128) not null,
	[counter_name] nvarchar(128) not null,
	[cntr_type] int null,
	[is_sql_counter] bit not null, 

	constraint pk_tmp_t 
	primary key clustered ([sql_instance],[object_name], [counter_name])
)


insert into #t with (tablock) ([sql_instance], [object_name], [counter_name], [cntr_type], [is_sql_counter]) 
select distinct 
		[sql_instance] = @@SERVERNAME
	, [object_name] = rtrim(pc.[object_name])
	, [counter_name] = rtrim(pc.[counter_name])
	, [cntr_type] = pc.[cntr_type]
	, [is_sql_counter] = 1
from sys.dm_os_performance_counters pc
		
union all
		
select 
	[sql_instance] = @@SERVERNAME
	, [object_name] = 'Win32_PerfFormattedData_PerfOS_Processor'
	, [counter_name] = 'Processor Time %'
	, [cntr_type] = 65792
	, [is_sql_counter] = 1 --this is faked from ring buffer. Perhaps we should change it now as we could get genuine counter from WMI via CLR


-- get non SQL counters via CLR if enabled:
if dbo.ufn_sqlwatch_get_clr_collector_status() = 1
	begin
		create table #c (
			object_name nvarchar(128),
			counter_name nvarchar(128),
			instance_name nvarchar(128)
		)

		insert into #c
		exec sp_executesql '
		select distinct *
		from dbo.ReadPerformanceCounterCategories()
		'

		create unique clustered index idx_tmp_c on #c ([object_name], [counter_name], instance_name)
		
		insert into #t with (tablock) ([sql_instance], [object_name], [counter_name], [cntr_type], [is_sql_counter]) 
		select distinct 
			  [sql_instance] = @@SERVERNAME
			, [object_name] = rtrim(pc1.[object_name])
			, [counter_name] = rtrim(pc1.[counter_name])
			, [cntr_type] = -1 --pc1.[cntr_type]
			, [is_sql_counter] = 0
		from #c pc1

		inner join dbo.[sqlwatch_config_performance_counters] sc with (nolock)
			on pc1.[object_name] like '%' + sc.[object_name] collate database_default
			and pc1.counter_name = sc.counter_name collate database_default
			and (
				pc1.instance_name = sc.instance_name collate database_default
				or	(
					sc.instance_name = '<* !_Total>' collate database_default
					and pc1.instance_name <> '_Total' collate database_default
					)
				)

		where sc.collect = 1
		--only non SQL Server Counters
		and pc1.[object_name] not like 'SQLServer%'
		and pc1.[object_name] not like 'MSSQL$%'

	end

;merge [dbo].[sqlwatch_meta_performance_counter] as target
using #t as source
	on target.sql_instance = source.sql_instance collate database_default
	and target.object_name = source.object_name collate database_default
	and target.counter_name = source.counter_name collate database_default

when matched and target.[is_sql_counter] is null then 
	update 
		set is_sql_counter = source.[is_sql_counter]

when not matched then
	insert ([sql_instance],[object_name],[counter_name],[cntr_type],[is_sql_counter])
	values (source.[sql_instance],source.[object_name],source.[counter_name],source.[cntr_type],source.[is_sql_counter]);


if dbo.ufn_sqlwatch_get_clr_collector_status() = 1
	begin
		---- while we're here, build distinct counter instances... this is currently only used to feed into the CLR function.
		---- in the future it will be used for all counters to reduce size of the counters logger
		;merge [dbo].[sqlwatch_meta_performance_counter_instance] as target
		using (
			select distinct 
				performance_counter_id, instance_name, mpc.sql_instance
			from #c c
			inner join [dbo].[sqlwatch_meta_performance_counter] mpc
			on mpc.sql_instance = @@SERVERNAME
			and mpc.object_name = c.object_name
			and mpc.counter_name = c.counter_name
			) as source
		on target.performance_counter_id = source.performance_counter_id
		and target.sql_instance = source.sql_instance
		and target.instance_name = source.instance_name

		when not matched then
			insert (performance_counter_id, instance_name, [sql_instance], [date_updated])
			values (source.performance_counter_id, source.instance_name, source.[sql_instance], getutcdate());
	end
