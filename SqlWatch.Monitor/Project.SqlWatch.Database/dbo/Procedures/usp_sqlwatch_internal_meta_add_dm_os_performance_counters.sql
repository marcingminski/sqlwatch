CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_meta_add_dm_os_performance_counters]
	@xdoc int,
	@sql_instance varchar(32)
as
begin
	set nocount on;

	select 
		[object_name]
		, counter_name
		, cntr_type
		, sql_instance = @sql_instance
	into #t
	from openxml (@xdoc, '/MetaDataSnapshot/dm_os_performance_counters/row',1) 
	with (
		[object_name] nvarchar(128),
		[counter_name] nvarchar(128),
		[cntr_type] int
	);

	;merge [dbo].[sqlwatch_meta_dm_os_performance_counters] with (serializable) as target
	using (
		select distinct 
			  [sql_instance] 
			, [object_name] = rtrim([object_name])
			, [counter_name] = rtrim([counter_name])
			, [cntr_type] = [cntr_type]
		from #t
		) as source
		on target.sql_instance = source.sql_instance collate database_default
		and target.object_name = source.object_name collate database_default
		and target.counter_name = source.counter_name collate database_default

	when matched and target.[is_sql_counter] is null then 
		update 
			set is_sql_counter = 1,
				[date_updated] = getutcdate()

	when not matched then
		insert ([sql_instance],[object_name],[counter_name],[cntr_type],[is_sql_counter])
		values (source.[sql_instance],source.[object_name],source.[counter_name],source.[cntr_type],1)

	option (keepfixed plan);
end;

