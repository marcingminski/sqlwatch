/*
Post-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.		
 Use SQLCMD syntax to include a file in the post-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the post-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/

--------------------------------------------------------------------------------------
-- THIS MUST BE THE FIRST STEP:
-- Load local server to satisfy RI
--------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Reference-Data\Script.PostDeployment-LoadMeta-Server.sql

--------------------------------------------------------------------------------------
-- Add Databases to the reference tables
--------------------------------------------------------------------------------------
exec [dbo].[usp_sqlwatch_internal_add_database]

--------------------------------------------------------------------------------------
-- Load Default Performance Counters
--------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Reference-Data\Script.PostDeployment-LoadConfig-PerformanceCounters.sql

--------------------------------------------------------------------------------------
-- Load Default Snapshot Types
--------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Reference-Data\Script.PostDeployment-LoadConfig-SnapshotTypes.sql

--------------------------------------------------------------------------------------
-- Load Default Exclusions
--------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Reference-Data\Script.PostDeployment-LoadConfig-DefaultExclusions.sql

--------------------------------------------------------------------------------------
-- DATA FIX: Se default Last Seen Dates When migrating from >2.0
--------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Data-Fixes\Script.PostDeployment-DataFix-SetDefaultLastSeenDates.sql

--------------------------------------------------------------------------------------
-- load default report styles:
--------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Reference-Data\Script.PostDeployment-CreateDefaultReportStyles.sql

--------------------------------------------------------------------------------------
-- Load Default Action Template
--------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Reference-Data\Script.PostDeployment-CreateDefaultActionTemplate.sql

--------------------------------------------------------------------------------------
-- Load Default actions that DO NOT call reports
--------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Reference-Data\Script.PostDeployment-CreateDefaultActions.sql
--------------------------------------------------------------------------------------
-- Load Default reports 
--------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Reference-Data\Script.PostDeployment-CreateDefaultReports.sql

--------------------------------------------------------------------------------------
-- Load actions that call reports we have just created
--------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Reference-Data\Script.PostDeployment-CreateDefaultReportActions.sql

-------------------------------------------------------------------------------------
-- Load default checks
--------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Reference-Data\Script.PostDeployment-CreateDefaultChecks.sql

-------------------------------------------------------------------------------------
-- Load Global Config
-------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Reference-Data\Script.PostDeployment-LoadConfig-Global.sql

-------------------------------------------------------------------------------------
-- Load Errorlog Default Collectoin
-------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Reference-Data\Script.PostDeployment-LoadConfig-DefaultErrorLog.sql

-------------------------------------------------------------------------------------
-- start XES
-------------------------------------------------------------------------------------
exec [dbo].[usp_sqlwatch_internal_start_xes]

-------------------------------------------------------------------------------------
-- Migrate Data
-------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Data-Fixes\Script.PostDeployment-DataFix-MigrateReportTime.sql

--------------------------------------------------------------------------------------
-- populate central repository tables to import
-- this will have no meaning on the remote instance but it will mean less steps
-- when turning it into a central repository
--------------------------------------------------------------------------------------
--more than one record in the sql_instance table assumes we're running central repository:
if (select count(*) from [dbo].[sqlwatch_config_sql_instance]) > 1
	begin
		Print 'Looks like this is a central repository so we''re going to populate tabels to import'
		exec [dbo].[usp_sqlwatch_repository_populate_tables_to_import]
	end

-------------------------------------------------------------------------------------
-- THIS MUST BE LAST STATEMENT IN THE PROCESS SO WE CAN RUN DATA-MIGRATIONS BASED
-- ON THE CURRENT VERSION. IF WE UPDATE VERSION BEFORE RUNNING DATA MIGRATION IT WILL
-- BE A DISASTER
--------------------------------------------------------------------------------------
insert into [dbo].[sqlwatch_app_version] ( [install_date], [sqlwatch_version] )
values (SYSDATETIMEOFFSET(), RTRIM(LTRIM(REPLACE(REPLACE('$(DacVersion)',CHAR(10),''),CHAR(13),''))))

--------------------------------------------------------------------------------------
--setup jobs
--we have to switch database to msdb but we also need to know which db jobs should run in so have to capture current database:
--------------------------------------------------------------------------------------
if (select case when @@VERSION like '%Express Edition%' then 1 else 0 end) = 0
	begin
		exec dbo.[usp_sqlwatch_config_create_default_agent_jobs]
	end

-------------------------------------------------------------------------------------
-- Make Constraints Trusted Again
-------------------------------------------------------------------------------------
:r .\Scripts\Post-Deployment\Data-Fixes\Script.PostDeployment-FixNonTrustedConstraints.sql

-------------------------------------------------------------------------------------
-- Retart queues
------------------------------------------------------------------------------------- 
-- don't start queues on install until version 4.x exec [dbo].[usp_sqlwatch_internal_restart_queues]

-------------------------------------------------------------------------------------
-- reset session counts
-------------------------------------------------------------------------------------
merge [dbo].[sqlwatch_stage_xes_exec_count] as target
using (
	select session_name = name
	from sys.dm_xe_session_targets t
	inner join sys.dm_xe_sessions s
	on t.event_session_address = s.address
	where t.target_name = 'event_file'
	and (
			s.name like 'SQLWATCH%'
		or	s.name = 'system_health'
		)
) as source
on source.session_name = target.session_name collate database_default

when matched then update
	set	  execution_count = 0
		, last_event_time = null

--remove any non existing sessions from our count table:
when not matched by source then
	delete

when not matched then
	insert (session_name, execution_count, last_event_time)
	values (source.session_name, 0, null);