CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_memory_clerk]
as

;merge [dbo].[sqlwatch_meta_memory_clerk] as target
using (
	select distinct 
		[clerk_name] = [type] 
	from sys.dm_os_memory_clerks s
	union all
	select [clerk_name] = 'OTHER'
	) as source
on target.[clerk_name] = source.[clerk_name] collate database_default
and target.[sql_instance] = @@SERVERNAME

--when matched then 
--	update set date_last_seen = getutcdate()

when not matched then
	insert ([sql_instance], [clerk_name])
	values (@@SERVERNAME, source.[clerk_name]);