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

if exists (
	select * 
	from [dbo].[ufn_sqlwatch_get_version]()
	where major = 2
	and minor = 2
	and patch <= 7287
	and build <= 38400
	) or (
		select count(*)
		from sqlwatch_logger_snapshot_header
		where report_time is null
		) > 0
	begin
		Print 'Migrating Report Time to Offset Time...'
		update sqlwatch_logger_snapshot_header
			set report_time = dateadd(mi, datepart(TZOFFSET,SYSDATETIMEOFFSET()), (CONVERT([smalldatetime],dateadd(minute,ceiling(datediff(second,(0),CONVERT([time],CONVERT([datetime],[snapshot_time])))/(60.0)),datediff(day,(0),[snapshot_time])))))
			where report_time is null
	end