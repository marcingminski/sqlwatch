CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_wait_type]
AS


;merge [dbo].[sqlwatch_meta_wait_stats] as target
using (
	select ws.*, [is_excluded] = case when ews.wait_type is not null then 1 else 0 end 
	from sys.dm_os_wait_stats ws
	left join [dbo].[sqlwatch_config_exclude_wait_stats] ews
		on ews.[wait_type] = ws.wait_type
	) as source
	on target.[wait_type] = source.[wait_type] collate database_default
	and target.[sql_instance] = @@SERVERNAME
		
when matched then 
	update set [is_excluded] = source.[is_excluded]

when not matched then 
	insert ([sql_instance], [wait_type], [is_excluded])
	values (@@SERVERNAME, source.[wait_type], source.[is_excluded]);