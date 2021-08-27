CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_meta_add_dm_os_memory_clerks]
	@xdoc int,
	@sql_instance varchar(32)
as
begin
	set nocount on;

	declare @sql nvarchar(max);

	declare @memory_clerks table (
		type varchar(60),
		sql_instance varchar(32)
	);

	insert into @memory_clerks (
		type
		, sql_instance
		)
	select 
		type
		, sql_instance = @sql_instance
	from openxml (@xdoc, '/MetaDataSnapshot/dm_os_memory_clerks/row',1) 
		with (type varchar(60));

	merge [dbo].[sqlwatch_meta_dm_os_memory_clerk] as target
	using (
	
		select distinct 
			  [clerk_name] = [type] 
			, sql_instance
		from @memory_clerks s
		union all
		select top 1 
			  [clerk_name] = 'OTHER'
			, sql_instance
		from @memory_clerks o

		) as source
	on target.[clerk_name] = source.[clerk_name] collate database_default
	and target.[sql_instance] = source.sql_instance

	when not matched then
		insert ([sql_instance], [clerk_name])
		values (source.sql_instance, source.[clerk_name]);
end;
