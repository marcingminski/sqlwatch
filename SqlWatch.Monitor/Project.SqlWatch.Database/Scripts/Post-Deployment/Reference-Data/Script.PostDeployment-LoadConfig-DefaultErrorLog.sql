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

--only do this on the fresh install becuase the end user could have removed our default records, we do not want to reload them
if (select count(*) from dbo.sqlwatch_app_version) <= 1
    begin
        declare @keywords table (
            [keyword] nvarchar(255) not null,
            [log_type_id] int not null
        );

        insert into @keywords
        values  ('Login failed for user', 1),
                ('I/O saturation', 1),
                ('I/O requests', 1)
        ;

        insert into [dbo].[sqlwatch_config_include_errorlog_keywords]
        select s.[keyword], s.[log_type_id]
        from @keywords s;
    end;
