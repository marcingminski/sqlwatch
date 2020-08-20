CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_wait_type]
AS


;merge [dbo].[sqlwatch_meta_wait_stats] as target
using sys.dm_os_wait_stats as source
	on target.[wait_type] = source.[wait_type] collate database_default
	and target.[sql_instance] = @@SERVERNAME
		
--when matched then 
--	update set [date_last_seen] = getutcdate()

when not matched then 
	insert ([sql_instance], [wait_type])
	values (@@SERVERNAME, source.[wait_type]);