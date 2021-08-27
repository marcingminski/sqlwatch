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
declare @active_days varchar(27) = 'Mon,Tue,Wed,Thu,Fri,Sat,Sun'
declare @active_hours varchar(5) = '00-23'
declare @timer_valid_from datetime2(0) = '1970-01-01'
declare @timer_valid_to datetime2(0) = '2099-12-31'

;merge [dbo].[sqlwatch_config_timer] as target 
using (
	
	--internal application processing and maintenance:
	select timer_id = 'CD0AA425-FBF6-410C-B216-9809B729C88A', timer_type = 'I', timer_desc = 'Ring Buffer Offloader (MUST run every 1 minute)', timer_seconds = 1 * 60, timer_active_days = @active_days
	union
	select timer_id = 'A5A7457B-865B-426D-AB4B-9DBC7257297B', timer_type = 'I', timer_desc = 'Broker Queue Status and Size Logger', timer_seconds = 1 * 60, timer_active_days = @active_days
	union	
	select timer_id = '290C4FF4-90BE-45C0-BC8F-8EE0F17EDF51', timer_type = 'I', timer_desc = 'Broker Cleanup', timer_seconds = 1 * 60 * 60, timer_active_days = @active_days
	union
	select timer_id = 'C4A9DF05-5E4C-4F4C-B292-B7D291A93B6F', timer_type = 'I', timer_desc = 'Process Checks ', timer_seconds = 1 * 60, timer_active_days = @active_days
	union
	select timer_id = '154FE9BE-4CCF-450E-8270-E718C12408C7', timer_type = 'I', timer_desc = 'Expand Checks ', timer_seconds = 1 * 60 * 60, timer_active_days = @active_days
	union
	select timer_id = 'FCD8FAD8-B598-4313-8BF9-1648A6F15869', timer_type = 'I', timer_desc = 'Data Retention', timer_seconds = 1 * 60 * 60, timer_active_days = @active_days
	union
	select timer_id = 'EFB8A583-B238-4468-AAEB-6EF8DE45029A', timer_type = 'I', timer_desc = '5 Minute Trends', timer_seconds = 1 * 60 * 5, timer_active_days = @active_days
	union
	select timer_id = 'A44B4166-3D12-49D3-B8DA-F793B75AE159', timer_type = 'I', timer_desc = '60 Minute Trends', timer_seconds = 1 * 60 * 60, timer_active_days = @active_days
	
	--data collection snapshots:
	union
	select timer_id = 'B273076A-5D10-4527-909F-955707905890', timer_type = 'C', timer_desc = 'Performance Collector', timer_seconds = 1 * 5, timer_active_days = @active_days
	union
	select timer_id = 'A2719CB0-D529-46D6-8EFE-44B44676B54B', timer_type = 'C', timer_desc = 'Failed Agent Jobs and Xes Waits', timer_seconds = 1 * 60, timer_active_days = @active_days
	union
	select timer_id = 'FDA18576-D2DC-4143-8BF1-CDDF1BAA72CB', timer_type = 'C', timer_desc = 'Xes Diagnostics and Long Queries', timer_seconds = 1 * 60 * 5, timer_active_days = @active_days
	union
	select timer_id = 'F65F11A7-25CF-4A4D-8A4F-C75B03FE083F', timer_type = 'C', timer_desc = 'Agent History', timer_seconds = 1 * 60 * 10, timer_active_days = @active_days
	union
	select timer_id = 'E623DC39-A79D-4F51-AAAD-CF6A910DD72A', timer_type = 'C', timer_desc = 'Disk Utilisation, Query and Proc Stats', timer_seconds = 1 * 60 * 60, timer_active_days = @active_days
	union
	select timer_id = 'D6AFF9F8-3CC3-4714-BCAA-7FC7A8E7AC5C', timer_type = 'C', timer_desc = 'Missing Indexes and System Configuration', timer_seconds = 1 * 60 * 60 * 6, timer_active_days = @active_days
	union
	select timer_id = 'B7686F08-DCAF-4EFC-94E8-3BD8D2C8E8A5', timer_type = 'C', timer_desc = 'Metadata Collector', timer_seconds = 1 * 60 * 60, timer_active_days = @active_days
	union
	select timer_id = 'E906CBD0-3FBC-4B06-9AC6-4632C0333922', timer_type = 'C', timer_desc = 'Index Usage Stats', timer_seconds = 1 * 60 * 60 * 24, timer_active_days = 'Sun'

) as source
on source.timer_id = target.timer_id

when matched then	
	update set 
		timer_type = source.timer_type
		, timer_desc = source.timer_desc
		, timer_seconds = source.timer_seconds
		, timer_active_days = source.timer_active_days
		, timer_active_hours_utc = @active_hours
		, timer_active_from_date_utc = @timer_valid_from
		, timer_active_to_date_utc = @timer_valid_to
		, timer_enabled = 1

when not matched then
	insert ( timer_id, timer_type, timer_desc, timer_seconds, timer_active_days, timer_active_hours_utc, timer_active_from_date_utc, timer_active_to_date_utc, timer_enabled )
	values ( source.timer_id, source.timer_type, source.timer_desc, source.timer_seconds, source.timer_active_days, @active_hours, @timer_valid_from, @timer_valid_to, 1 );


;merge [dbo].[sqlwatch_config_snapshot_type] as target
using (
	select [snapshot_type_id] = 1, [snapshot_type_desc] = 'Performance', [snapshot_retention_days] = 8, timer_id = 'B273076A-5D10-4527-909F-955707905890'
	union 
	select [snapshot_type_id] = 2, [snapshot_type_desc] = 'Disk Utilisation Database', [snapshot_retention_days] = 365, timer_id = 'E623DC39-A79D-4F51-AAAD-CF6A910DD72A'
	union 
	select [snapshot_type_id] = 3, [snapshot_type_desc] = 'Missing indexes', [snapshot_retention_days] = 32, timer_id = 'D6AFF9F8-3CC3-4714-BCAA-7FC7A8E7AC5C'
	union 
	select [snapshot_type_id] = 6, [snapshot_type_desc] = 'XES Waits', [snapshot_retention_days] = 32, timer_id = 'A2719CB0-D529-46D6-8EFE-44B44676B54B'
	--union
	--select [snapshot_type_id] = 7, [snapshot_type_desc] = 'XES Long Queries', [snapshot_retention_days] = 8, timer_id = 'FDA18576-D2DC-4143-8BF1-CDDF1BAA72CB'
	union
	select [snapshot_type_id] = 8, [snapshot_type_desc] = 'XES Wait Queries (NOT USED)', [snapshot_retention_days] = 8, timer_id = null
	union
	select [snapshot_type_id] = 9, [snapshot_type_desc] = 'XES Blockers and Deadlocks', [snapshot_retention_days] = 32, timer_id = 'B273076A-5D10-4527-909F-955707905890'
	union
	select [snapshot_type_id] = 10, [snapshot_type_desc] = 'XES Diagnostics', [snapshot_retention_days] = 32, timer_id = 'FDA18576-D2DC-4143-8BF1-CDDF1BAA72CB'
	union
	select [snapshot_type_id] = 11, [snapshot_type_desc] = 'WhoIsActive', [snapshot_retention_days] = 3, timer_id = null
	union
	select [snapshot_type_id] = 14, [snapshot_type_desc] = 'Index Stats', [snapshot_retention_days] = 7, timer_id = 'E906CBD0-3FBC-4B06-9AC6-4632C0333922'
	union
	select [snapshot_type_id] = 15, [snapshot_type_desc] = 'Index Histogram', [snapshot_retention_days] = -1, timer_id = null
	union
	select [snapshot_type_id] = 16, [snapshot_type_desc] = 'Agent History', [snapshot_retention_days] = 30, timer_id = 'F65F11A7-25CF-4A4D-8A4F-C75B03FE083F'
	union
	select [snapshot_type_id] = 17, [snapshot_type_desc] = 'Disk Utilisation OS (WMI)', [snapshot_retention_days] = 365, timer_id = 'E623DC39-A79D-4F51-AAAD-CF6A910DD72A'
	union
	select [snapshot_type_id] = 18, [snapshot_type_desc] = 'Checks', [snapshot_retention_days] = 8, timer_id = '290C4FF4-90BE-45C0-BC8F-8EE0F17EDF51'
	union
	select [snapshot_type_id] = 19, [snapshot_type_desc] = 'Actions', [snapshot_retention_days] = 2, timer_id = '290C4FF4-90BE-45C0-BC8F-8EE0F17EDF51'
	union
	select [snapshot_type_id] = 20, [snapshot_type_desc] = 'Reports', [snapshot_retention_days] = 2, timer_id = '290C4FF4-90BE-45C0-BC8F-8EE0F17EDF51'
	union
	select [snapshot_type_id] = 21, [snapshot_type_desc] = 'N/A', [snapshot_retention_days] = 7, timer_id = null
	union
	select [snapshot_type_id] = 22, [snapshot_type_desc] = 'Disk Utilisation Table', [snapshot_retention_days] = 30, timer_id = 'E623DC39-A79D-4F51-AAAD-CF6A910DD72A'
	union
	select [snapshot_type_id] = 25, [snapshot_type_desc] = 'ERRORLOG', [snapshot_retention_days] = 30, timer_id = null
	union
	select [snapshot_type_id] = 26, [snapshot_type_desc] = 'System Configuration', [snapshot_retention_days] = 365, timer_id = 'D6AFF9F8-3CC3-4714-BCAA-7FC7A8E7AC5C' 
	union
	select [snapshot_type_id] = 27, [snapshot_type_desc] = 'Procedure Stats', [snapshot_retention_days] = 32, timer_id = 'E623DC39-A79D-4F51-AAAD-CF6A910DD72A'
	union
	select [snapshot_type_id] = 28, [snapshot_type_desc] = 'Query Stats', [snapshot_retention_days] = 32, timer_id = 'E623DC39-A79D-4F51-AAAD-CF6A910DD72A'
	union
	select [snapshot_type_id] = 29, [snapshot_type_desc] = 'Availability Groups', [snapshot_retention_days] = 32, timer_id = 'B273076A-5D10-4527-909F-955707905890'
	union
	select [snapshot_type_id] = 30, [snapshot_type_desc] = 'Exec Requests and Sessions', [snapshot_retention_days] = 32, timer_id = 'B273076A-5D10-4527-909F-955707905890'
	union
	select [snapshot_type_id] = 31, [snapshot_type_desc] = 'XES Query Problems', [snapshot_retention_days] = 2, timer_id = null
	union
	select [snapshot_type_id] = 32, [snapshot_type_desc] = 'Agent History (failed jobs)', [snapshot_retention_days] = 32, timer_id = 'A2719CB0-D529-46D6-8EFE-44B44676B54B'
	union
	select [snapshot_type_id] = 33, [snapshot_type_desc] = '5 Minute Trends', [snapshot_retention_days] = 32, timer_id = 'EFB8A583-B238-4468-AAEB-6EF8DE45029A'
	union
	select [snapshot_type_id] = 34, [snapshot_type_desc] = '60 Minute Trends', [snapshot_retention_days] = 720, timer_id = 'A44B4166-3D12-49D3-B8DA-F793B75AE159'
	union
	select [snapshot_type_id] = 35, [snapshot_type_desc] = 'SQLWATCH Collector Queue Size', [snapshot_retention_days] = 30, timer_id = 'A5A7457B-865B-426D-AB4B-9DBC7257297B'

) as source
on (source.[snapshot_type_id] = target.[snapshot_type_id])

when matched then
	update set 
		[snapshot_type_desc] = source.[snapshot_type_desc],
		timer_id = source.timer_id

when not matched then
	insert ([snapshot_type_id],[snapshot_type_desc],[snapshot_retention_days], timer_id)
	values (source.[snapshot_type_id],source.[snapshot_type_desc],source.[snapshot_retention_days], source.timer_id)
;