CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_expand_checks]
as
begin

	set nocount on ;

	declare @check_name varchar(255),
			@expand_by varchar(50),
			@check_template_id smallint;

	declare cur_expand_check cursor LOCAL FAST_FORWARD for
	select check_name, expand_by, check_template_id
	from [dbo].[sqlwatch_config_check_template]
	where template_enabled = 1

	open cur_expand_check 
	
	fetch next from cur_expand_check 
		into @check_name, @expand_by , @check_template_id
	
	while @@FETCH_STATUS = 0 
	begin

		declare @checks table (	
			[check_template_id] smallint,
			[check_name] [nvarchar](255) NOT NULL,
			[check_description] [nvarchar](2048) NULL,
			[check_query] [nvarchar](max) NOT NULL,
			[check_frequency_minutes] [smallint] NULL,
			[check_threshold_warning] [varchar](100) NULL,
			[check_threshold_critical] [varchar](100) NOT NULL,
			[check_enabled] [bit] NOT NULL,
			[ignore_flapping] [bit] NOT NULL
		)

		if @expand_by is null
			begin
				insert into @checks (
						[check_name],[check_description],[check_query],[check_frequency_minutes],[check_threshold_warning]
					   ,[check_threshold_critical],[check_enabled],[ignore_flapping],[check_template_id]
				)

				select 
				    [check_name]
				   ,[check_description]
				   ,[check_query]
				   ,[check_frequency_minutes]
				   ,[check_threshold_warning]
				   ,[check_threshold_critical]
				   ,[check_enabled]
				   ,[ignore_flapping]
				   ,[check_template_id]
				from [dbo].[sqlwatch_config_check_template] c
				where c.check_name = @check_name
			end

		if @expand_by = 'Disk'
			begin
				insert into @checks (
						[check_name],[check_description],[check_query],[check_frequency_minutes],[check_threshold_warning]
					   ,[check_threshold_critical],[check_enabled],[ignore_flapping],[check_template_id]
				)

				select 
				   [check_name]=case 
							when c.check_name like '%{Disk}%' then replace(c.check_name,'{Disk}',d.[volume_name]) 
							else c.check_name + ' (' + d.[volume_name] + ')' end
				   ,[check_description]=case when [check_description] like '%{Disk}%'
											then replace([check_description],'{Disk}',d.[volume_name])
											else [check_description] end
				   ,[check_query]=replace([check_query],'{Disk}',d.[volume_name])
				   ,[check_frequency_minutes]
				   ,[check_threshold_warning]
				   ,[check_threshold_critical]
				   ,[check_enabled]
				   ,[ignore_flapping]
				   ,[check_template_id]
				from [dbo].[sqlwatch_config_check_template] c
				cross apply [dbo].[sqlwatch_meta_os_volume] d
				where c.check_name = @check_name
				and c.expand_by = @expand_by
			end

		if @expand_by = 'Job'
			begin
				insert into @checks (
						[check_name],[check_description],[check_query],[check_frequency_minutes],[check_threshold_warning]
					   ,[check_threshold_critical],[check_enabled],[ignore_flapping],[check_template_id]
				)

				select 
				   [check_name]=case 
							when c.check_name like '%{JOB}%' then replace(c.check_name,'{JOB}',d.[name]) 
							else c.check_name + ' (' + d.[name] + ')' end
				   ,[check_description]=case when [check_description] like '%{JOB}%'
											then replace([check_description],'{JOB}',d.[name])
											else [check_description] end
				   ,[check_query]=replace([check_query],'{JOB}',d.[name])
				   ,[check_frequency_minutes]
				   ,[check_threshold_warning]
				   ,[check_threshold_critical]
				   ,[check_enabled]
				   ,[ignore_flapping]
				   ,[check_template_id]
				from [dbo].[sqlwatch_config_check_template] c
				cross apply msdb.dbo.sysjobs d
				where c.check_name = @check_name
				and c.expand_by = @expand_by
			end

		if @expand_by = 'Database'
			begin

				insert into @checks (
						[check_name],[check_description],[check_query],[check_frequency_minutes],[check_threshold_warning]
					   ,[check_threshold_critical],[check_enabled],[ignore_flapping],[check_template_id]
				)

				select 
				   [check_name]=case 
							when c.check_name like '%{DATABASE}%' then replace(c.check_name,'{DATABASE}',d.[name]) 
							else c.check_name + ' (' + d.[name] + ')' end
				   ,[check_description]=case when [check_description] like '%{DATABASE}%'
											then replace([check_description],'{DATABASE}',d.[name])
											else [check_description] end
				   ,[check_query]=replace([check_query],'{DATABASE}',d.[name])
				   ,[check_frequency_minutes]
				   ,[check_threshold_warning]
				   ,[check_threshold_critical]
				   ,[check_enabled]
				   ,[ignore_flapping]
				   ,[check_template_id]
				from [dbo].[sqlwatch_config_check_template] c
				cross apply dbo.vw_sqlwatch_sys_databases d
				where c.check_name = @check_name
				and c.expand_by = @expand_by
			end

		fetch next from cur_expand_check 
			into @check_name, @expand_by, @check_template_id
	end

	close cur_expand_check
	deallocate cur_expand_check;


	;merge [dbo].[sqlwatch_config_check] as target 
	using @checks as source
	on target.check_name = source.check_name

	when not matched by target then
		insert (
				 [check_name]
				,[check_description]
				,[check_query]
				,[check_frequency_minutes]
				,[check_threshold_warning]
				,[check_threshold_critical]
				,[check_enabled]
				,[date_created]
				,[date_updated]
				,[ignore_flapping]
				,[check_template_id]
				)
		values ( 
				 [check_name]
				,[check_description]
				,[check_query]
				,[check_frequency_minutes]
				,[check_threshold_warning]
				,[check_threshold_critical]
				,[check_enabled]
				,getutcdate()
				,getutcdate()
				,[ignore_flapping]
				,[check_template_id]
				)

		when not matched by source 
		and target.[check_template_id] = @check_template_id then delete

		-- if the user sets the check as "user modified" we will not update it		
		when matched and isnull(target.user_modified,0) = 0 then 
			update 
				set [check_name] = source.[check_name]
				,[check_description] = source.[check_description]
				,[check_query] = source.[check_query]
				,[check_frequency_minutes] = source.[check_frequency_minutes]
				,[check_threshold_warning] = source.[check_threshold_warning]
				,[check_threshold_critical] = source.[check_threshold_critical]
				,[check_enabled] = source.[check_enabled]
				,[date_updated] = getutcdate()
				,[ignore_flapping] = source.[ignore_flapping];



		-- load action templates:
		merge [dbo].[sqlwatch_config_check_action] as target
		using (
			select 
				cc.[check_id]
			   ,a.[action_id]
			   ,a.[action_every_failure]
			   ,a.[action_recovery]
			   ,a.[action_repeat_period_minutes]
			   ,a.[action_hourly_limit]
			   ,a.[action_template_id]
			   ,[date_created]=GETUTCDATE()
			   ,[date_updated]=GETUTCDATE()
		
			from @checks c
			inner join [dbo].[sqlwatch_config_check_template]  ct
				on ct.check_template_id = c.check_template_id
			inner join [dbo].[sqlwatch_config_check_template_action] a
				on a.check_name = ct.check_name
			inner join [dbo].[sqlwatch_config_check] cc
				on cc.check_name = ct.check_name
			) as source
		on source.check_id = target.check_id
		and source.action_id = target.action_id

		when not matched then
			insert ([check_id]
           ,[action_id]
           ,[action_every_failure]
           ,[action_recovery]
           ,[action_repeat_period_minutes]
           ,[action_hourly_limit]
           ,[action_template_id]
           ,[date_created]
           ,[date_updated])
		   
		   values (
			source.[check_id]
           ,source.[action_id]
           ,source.[action_every_failure]
           ,source.[action_recovery]
           ,source.[action_repeat_period_minutes]
           ,source.[action_hourly_limit]
           ,source.[action_template_id]
           ,source.[date_created]
           ,source.[date_updated]
		   );

end
