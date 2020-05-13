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
;merge [dbo].[sqlwatch_config_snapshot_type] as target
using (
	/* performance data logger */
	select [snapshot_type_id] = 1, [snapshot_type_desc] = 'Performance', [snapshot_retention_days] = 8
	union 
	/* size data logger */
	select [snapshot_type_id] = 2, [snapshot_type_desc] = 'Disk Utilisation Database', [snapshot_retention_days] = 365
	union 
	/* indexes */
	select [snapshot_type_id] = 3, [snapshot_type_desc] = 'Missing indexes', [snapshot_retention_days] = 32
	union 
	/* XES Waits */
	select [snapshot_type_id] = 6, [snapshot_type_desc] = 'XES Waits', [snapshot_retention_days] = 8
	union
	/* XES SQLWATCH Long queries */
	select [snapshot_type_id] = 7, [snapshot_type_desc] = 'XES Long Queries', [snapshot_retention_days] = 8
	union
	/* XES SQLWATCH Waits */
	select [snapshot_type_id] = 8, [snapshot_type_desc] = 'XES Waits', [snapshot_retention_days] = 32  --is this used
	union
	/* XES SQLWATCH Blockers */
	select [snapshot_type_id] = 9, [snapshot_type_desc] = 'XES Blockers', [snapshot_retention_days] = 32
	union
	/* XES diagnostics */
	select [snapshot_type_id] = 10, [snapshot_type_desc] = 'XES Query Processing', [snapshot_retention_days] = 32
	union
	/* whoisactive */
	select [snapshot_type_id] = 11, [snapshot_type_desc] = 'WhoIsActive', [snapshot_retention_days] = 3
	union
	/* index usage */
	select [snapshot_type_id] = 14, [snapshot_type_desc] = 'Index Stats', [snapshot_retention_days] = 7
	union
	/* index histogram */
	select [snapshot_type_id] = 15, [snapshot_type_desc] = 'Index Histogram', [snapshot_retention_days] = -1
	union
	/* agent history */
	select [snapshot_type_id] = 16, [snapshot_type_desc] = 'Agent History', [snapshot_retention_days] = 30
	union
	/* Os volume utilisation */
	select [snapshot_type_id] = 17, [snapshot_type_desc] = 'Disk Utilisation OS', [snapshot_retention_days] = 365
	union
	/* Checks History */
	select [snapshot_type_id] = 18, [snapshot_type_desc] = 'Checks', [snapshot_retention_days] = 8
	union
	/* Actions History */
	select [snapshot_type_id] = 19, [snapshot_type_desc] = 'Actions', [snapshot_retention_days] = 2
	union
	/* Reports History */
	select [snapshot_type_id] = 20, [snapshot_type_desc] = 'Reports', [snapshot_retention_days] = 2
	union
	/* Error Logging */
	select [snapshot_type_id] = 21, [snapshot_type_desc] = 'N/A', [snapshot_retention_days] = 7
	union
	/* Table Size */
	select [snapshot_type_id] = 22, [snapshot_type_desc] = 'Disk Utilisation Table', [snapshot_retention_days] = 30
	union
	/* Errorlog */
	select [snapshot_type_id] = 25, [snapshot_type_desc] = 'ERRORLOG', [snapshot_retention_days] = 30
	UNION
	/* System Configuration */
	select [snapshot_type_id] = 26, [snapshot_type_desc] = 'System Configuration', [snapshot_retention_days] = 365 

) as source
on (source.[snapshot_type_id] = target.[snapshot_type_id])
when matched and source.[snapshot_type_desc] <> target.[snapshot_type_desc] then
	update set [snapshot_type_desc] = source.[snapshot_type_desc]
when not matched then
	insert ([snapshot_type_id],[snapshot_type_desc],[snapshot_retention_days])
	values (source.[snapshot_type_id],source.[snapshot_type_desc],source.[snapshot_retention_days])
;