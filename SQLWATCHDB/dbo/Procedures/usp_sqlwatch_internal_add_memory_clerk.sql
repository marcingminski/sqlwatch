CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_memory_clerk]
as

insert into [dbo].[sqlwatch_meta_memory_clerk] ([sql_instance], [clerk_name])
select [sql_instance]=@@SERVERNAME, [type]
from (
	select distinct [type] 
	from sys.dm_os_memory_clerks s
	union all
	select 'OTHER'
) s
left join [dbo].[sqlwatch_meta_memory_clerk] d
	on d.[clerk_name] = s.[type] collate database_default
	and d.sql_instance = @@SERVERNAME
where d.[clerk_name] is null