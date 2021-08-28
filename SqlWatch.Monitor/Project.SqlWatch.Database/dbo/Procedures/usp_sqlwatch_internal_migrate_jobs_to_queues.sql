--CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_migrate_jobs_to_queues]
--as

----this procedure will disable and remove the relevent agent jobs and enable broker based collection
--declare @sql varchar(max) = '',
--		@database_name sysname = db_name()

--select @sql = @sql  + ';' + char(10) + 'exec msdb.dbo.sp_delete_job @job_id=N'''+ convert(varchar(255),job_id) +''', @delete_unused_schedule=1' 
--from msdb.dbo.sysjobs
--where name like case when @database_name <> 'SQLWATCH' then 'SQLWATCH-\[' + @database_name + '\]%' else 'SQLWATCH-%' end  escape '\'
--  and name not like case when @database_name = 'SQLWATCH' then 'SQLWATCH-\[%' else '' end  escape '\'
--and name not like '%AZMONITOR'
--and name not like '%ACTIONS'
--and name not like '%DISK-UTILISATION'
--and name not like '%INDEXES'
--and name not like '%WHOISACTIVE'

--exec (@sql);


---- activate queues:
--exec [dbo].[usp_sqlwatch_internal_restart_queues];

---- update config so the next deployment is aware of the migration:
--update dbo.sqlwatch_config
--set config_value = 1
--where config_id = 13
--and config_value = 0