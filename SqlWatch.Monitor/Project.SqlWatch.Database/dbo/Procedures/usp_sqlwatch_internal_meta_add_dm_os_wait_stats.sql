CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_meta_add_dm_os_wait_stats]
	@xdoc int,
	@sql_instance varchar(32)
as
begin
	set nocount on;

	merge [dbo].[sqlwatch_meta_dm_os_wait_stats] with (serializable) as target
	using (
		select distinct 
			  ws.wait_type
			, sql_instance = @sql_instance
			, is_excluded = case when ews.wait_type is not null then 1 else 0 end
		from openxml (@xdoc, '/MetaDataSnapshot/dm_os_wait_stats/row',1) 
		with (
			wait_type nvarchar(60)
		) ws
		outer apply(
			select top 1 wait_type 
			from [dbo].[sqlwatch_config_exclude_wait_stats] ews
			where ws.wait_type = ews.wait_type collate database_default) ews
		)
		as source
		on target.[wait_type] = source.[wait_type] collate database_default
		and target.[sql_instance] = source.sql_instance 
		
	when matched then 
		update set [is_excluded] = source.[is_excluded],
				date_updated = getutcdate()

	when not matched then 
		insert ([sql_instance], [wait_type], [is_excluded])
		values (source.sql_instance, source.[wait_type], source.[is_excluded]);
end;

