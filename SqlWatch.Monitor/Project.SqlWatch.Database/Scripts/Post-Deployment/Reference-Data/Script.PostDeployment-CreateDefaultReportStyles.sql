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
if not exists (select * from [dbo].[sqlwatch_config_report_style] where [report_style_id] = -1)
	begin
		set identity_insert [dbo].[sqlwatch_config_report_style] on
		insert into [dbo].[sqlwatch_config_report_style] ([report_style_id], [style])
		values (-1,'body {font-family: "Trebuchet MS",Helvetica,sans-serif; font-size: 12px;}
table.sqlwatchtbl { border: 1px solid #AAAAAA; background-color: #FEFEFE; width: 100%; text-align: left; border-collapse: collapse; }
table.sqlwatchtbl td, table.sqlwatchtbl th { border: 1px solid #AAAAAA; padding: 3px 3px; }
table.sqlwatchtbl tbody td { color: #333333; }
table.sqlwatchtbl tr:nth-child(even) { background: #EEEEEE; }
table.sqlwatchtbl thead { background: #7C008C; }
table.sqlwatchtbl thead th { font-size: 12px; font-weight: bold; color: #FFFFFF;}
.code {display:block;background:#ddd; margin-top:0.8em;padding-left:10px;padding-bottom:1em;white-space: pre;}'
)
		set identity_insert [dbo].[sqlwatch_config_report_style] off;
	end