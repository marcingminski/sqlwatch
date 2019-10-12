CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_wait_type]
AS

		
insert into [dbo].[sqlwatch_meta_wait_stats] ([sql_instance], [wait_type])
select distinct @@SERVERNAME, dm.[wait_type]
from sys.dm_os_wait_stats dm
left join [dbo].[sqlwatch_meta_wait_stats] ws
	on ws.[sql_instance] = @@SERVERNAME
	and ws.[wait_type] = dm.[wait_type] collate database_default
where ws.[wait_type] is null
