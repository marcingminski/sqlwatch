CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_meta_add_system_configuration]
	@xdoc int,
	@sql_instance varchar(32)
as
begin
	set nocount on;

	merge [dbo].[sqlwatch_meta_system_configuration] as target
	using (
			select distinct
				[sql_instance] = @sql_instance
				 , [configuration_id]
				 , [name]
				 , [value]
				 , [value_in_use]
				 , [description]
			from openxml (@xdoc, '/CollectionSnapshot/sys_configurations/row',1) 
				with (
					[configuration_id] int
					, [name] nvarchar(35)
					, [value] int
					, [value_in_use] int
					, [description] nvarchar(255)
				)
			) as source
	on target.configuration_id = source.configuration_id
	and target.[sql_instance] = source.[sql_instance]

	when matched 
		and (
				target.[value] <> source.[value] 
			or	target.[value_in_use] <> source.[value_in_use]
			)
		then 
		update set [value] = source.[value],
			[value_in_use] = source.[value_in_use]

	when not matched by target then
		insert ([sql_instance], [configuration_id], [name], [description], [value], [value_in_use], [date_created])
		values (source.[sql_instance], source.[configuration_id], source.[name], source.[description], source.[value], source.[value_in_use], GETUTCDATE());
end;