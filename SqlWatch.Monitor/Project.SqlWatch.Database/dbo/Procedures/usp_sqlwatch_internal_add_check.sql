CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_check]
	@check_name nvarchar(50) ,
	@check_description nvarchar(2048) ,
	@check_query nvarchar(max)  ,
	@check_frequency_minutes smallint ,
	@check_threshold_warning varchar(100) ,
	@check_threshold_critical varchar(100) ,
	@check_enabled bit = 1,
	@notification_target_id smallint ,
	@notification_enabled bit = 1,
	@notify_every_failure bit = 0,
	@notify_recovery bit = 1,
	@notification_repeat_period_minutes smallint
as

declare @checks as table(
	[sql_instance] varchar(32) not null default @@SERVERNAME,
	[check_name] nvarchar(50) not null,
	[check_description] nvarchar(2048) null,
	[check_query] nvarchar(max) not null,
	[check_frequency_minutes] smallint null,
	[check_threshold_warning] varchar(100) null,
	[check_threshold_critical] varchar(100) null,
	[check_enabled] bit not null default 1,
	[notification_target_id] smallint null,
	[notification_enabled] bit not null default 1,
	[notify_every_failure] bit not null default 0,
	[notify_recovery] bit not null default 1,
	[notification_repeat_period_minutes] smallint null
	primary key clustered (
		[check_name]
	)
) 

--insert into @checks
--select [sql_instance] = @@SERVERNAME
--	,  [check_name] = @check_name
--	,  [check_description] = @check_description
--	,  [check_query] = @check_query
--	,  [check_frequency_minutes] = @check_frequency_minutes
--	,  [check_threshold_warning] = @check_threshold_warning
--	,  [check_threshold_critical] = @check_threshold_critical
--	,  [check_enabled] = @check_enabled
--	,  [notification_target_id] = @notification_target_id
--	,  [notification_enabled] = @notification_enabled
--	,  [notify_every_failure] = @notify_every_failure
--	,  [notify_recovery]= @notify_recovery
--	,  [notification_repeat_period_minutes] = @notification_repeat_period_minutes



--merge [dbo].[sqlwatch_config_check] as target
--using @checks as source
--on source.sql_instance = target.sql_instance
--and source.check_name = target.check_name
--and source.check_query = target.check_query
----when not matched by source then 
----	delete
--when not matched by target then
--	insert ([sql_instance],
--			[check_name] ,
--			[check_description] ,
--			[check_query] ,
--			[check_frequency_minutes],
--			[check_threshold_warning],
--			[check_threshold_critical],
--			[check_enabled],
--			[delivery_target_id],
--			[delivery_enabled],
--			[deliver_every_failure],
--			[deliver_recovery],
--			[delivery_repeat_period_minutes])
--	values (source.[sql_instance],
--			source.[check_name] ,
--			source.[check_description] ,
--			source.[check_query] ,
--			source.[check_frequency_minutes],
--			source.[check_threshold_warning],
--			source.[check_threshold_critical],
--			source.[check_enabled],
--			source.[notification_target_id],
--			source.[notification_enabled],
--			source.[notify_every_failure],
--			source.[notify_recovery],
--			source.[notification_repeat_period_minutes]);