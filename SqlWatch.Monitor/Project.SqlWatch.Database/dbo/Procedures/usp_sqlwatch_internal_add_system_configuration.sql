CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_system_configuration]
as

merge [dbo].[sqlwatch_meta_system_configuration] as target
using (
		select [sql_instance]
		     , [configuration_id]
			 , [name]
			 , [value]
			 , [value_in_use]
			 , [description]
		from dbo.vw_sqlwatch_sys_configurations
		) as source
on target.configuration_id = source.configuration_id
and target.[sql_instance] = source.[sql_instance]

when matched then 
	update set [value] = source.[value],
		[value_in_use] = source.[value_in_use],
		[date_updated] = case when 		
									target.[value] <> source.[value]
								or	target.[value_in_use] <> source.[value_in_use]
								then GETUTCDATE() else [date_updated] end,
		[date_last_seen] = GETUTCDATE(),
		[is_record_deleted] = 0

when not matched by target then
	insert ([sql_instance], [configuration_id], [name], [description], [value], [value_in_use], [date_created], [date_last_seen])
	values (source.[sql_instance], source.[configuration_id], source.[name], source.[description], source.[value], source.[value_in_use], GETUTCDATE(), GETUTCDATE());


