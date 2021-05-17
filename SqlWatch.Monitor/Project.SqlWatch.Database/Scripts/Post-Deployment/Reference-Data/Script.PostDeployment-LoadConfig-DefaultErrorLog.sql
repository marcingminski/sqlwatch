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

declare @keywords table (
    [keyword1] nvarchar(255) not null,
    [keyword2] nvarchar(255) null,
    [log_type_id] int not null
);

--only do this on the fresh install becuase the end user could have removed our default records, we do not want to reload them
if (select count(*) from dbo.sqlwatch_app_version) < 1
    begin
        insert into @keywords (keyword1, keyword2, log_type_id)
        values  ('Login failed for user', null,1)
        ;

        merge [dbo].[sqlwatch_config_include_errorlog_keywords] as target
        using @keywords as source 
        on source.[keyword1] = target.[keyword1]
        and isnull(source.[keyword2],'') = isnull(target.[keyword2],'')
        and source.[log_type_id] = target.[log_type_id]
        
        when not matched then 
            insert (keyword1, [keyword2], [log_type_id])
            values (source.[keyword1], source.[keyword2], source.[log_type_id]);
    end;

--We need this all the time, if the user deleted it, we have to add it back in:
delete from @keywords;

insert into @keywords (keyword1, keyword2, log_type_id)
values  ('I/O saturation', null,1),
        ('I/O requests', null,1),
        ('sqlwatch_exec', 'Error',1),
        ('sqlwatch_exec', 'failed',1)
        ;

merge [dbo].[sqlwatch_config_include_errorlog_keywords] as target
using @keywords as source 
on source.[keyword1] = target.[keyword1]
and isnull(source.[keyword2],'') = isnull(target.[keyword2],'')
and source.[log_type_id] = target.[log_type_id]
        
when not matched then 
    insert (keyword1, [keyword2], [log_type_id])
    values (source.[keyword1], source.[keyword2], source.[log_type_id]);