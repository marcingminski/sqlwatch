CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_expand_checks]
as
begin

	set nocount on ;

	declare @check_name varchar(255),
			@expand_by varchar(50),
			@check_template_id smallint,
			@sql_instance varchar(32);

	declare cur_expand_by_server cursor for
	select [sql_instance]
	from dbo.sqlwatch_config_sql_instance
	--only expand by all instances if set in the config, otherwise just expand by local instance
	where sql_instance = case when dbo.ufn_sqlwatch_get_config_value (19, null) = 1 
		then sql_instance 
		else dbo.ufn_sqlwatch_get_servername()
		end;

	open cur_expand_by_server

	fetch next from cur_expand_by_server
		into @sql_instance

	while @@FETCH_STATUS = 0
	begin

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
				[ignore_flapping] [bit] NOT NULL,
				[object_type] varchar(50),
				[object_name] nvarchar(128),
				[target_sql_instance] varchar(32),
				[use_baseline] bit
			)

			if @expand_by is null
				begin
					insert into @checks (
							[check_name],[check_description],[check_query],[check_frequency_minutes],[check_threshold_warning]
						   ,[check_threshold_critical],[check_enabled],[ignore_flapping],[check_template_id], [target_sql_instance]
						   ,[use_baseline]
					)

					select 
						[check_name]
					   ,[check_description]
					   ,[check_query]=replace(check_query,'{SQL_INSTANCE}',@sql_instance)
					   ,[check_frequency_minutes]
					   ,[check_threshold_warning]
					   ,[check_threshold_critical]
					   ,[check_enabled]
					   ,[ignore_flapping]
					   ,[check_template_id]
					   ,@sql_instance
					   ,[use_baseline]
					from [dbo].[sqlwatch_config_check_template] c
					where c.check_name = @check_name
				end

			if @expand_by = 'Disk'
				begin
					insert into @checks (
							[check_name],[check_description],[check_query],[check_frequency_minutes],[check_threshold_warning]
						   ,[check_threshold_critical],[check_enabled],[ignore_flapping],[check_template_id], [object_type], [object_name]
						   ,[target_sql_instance]
						   ,[use_baseline]
					)

					select 
					   [check_name]=case 
								when c.check_name like '%{Disk}%' then replace(c.check_name,'{Disk}',d.[volume_name]) 
								else c.check_name + ' (' + d.[volume_name] + ')' end 
					   ,[check_description]=case when [check_description] like '%{Disk}%'
												then replace([check_description],'{Disk}',d.[volume_name])
												else [check_description] end
					   ,[check_query]= replace(replace([check_query],'{Disk}',d.[volume_name]),'{SQL_INSTANCE}',@sql_instance)
					   ,[check_frequency_minutes]
					   ,[check_threshold_warning]
					   ,[check_threshold_critical]
					   ,[check_enabled]
					   ,[ignore_flapping]
					   ,[check_template_id]
					   ,[object_type] = @expand_by
					   ,[object_name] = d.[volume_name]
					   ,@sql_instance 
					   ,[use_baseline]
					from [dbo].[sqlwatch_config_check_template] c
					cross apply (
						select *
						from [dbo].[sqlwatch_meta_os_volume]
						where sql_instance = @sql_instance
						) d
					where c.check_name = @check_name
					and c.expand_by = @expand_by
					and d.sql_instance = @sql_instance
				end

			if @expand_by = 'Job'
				begin
					insert into @checks (
							[check_name],[check_description],[check_query],[check_frequency_minutes],[check_threshold_warning]
						   ,[check_threshold_critical],[check_enabled],[ignore_flapping],[check_template_id], [object_type], [object_name]
						   ,[target_sql_instance]
						   ,[use_baseline]
					)

					--this use to point to sysjobs hence the collate, I don't think we need collate anymore as within the db scope.
					select 
					   [check_name]=case 
								when c.check_name like '%{JOB}%' then replace(c.check_name,'{JOB}',d.[job_name] collate database_default) 
								else c.check_name + ' (' + d.[job_name] collate database_default + ')' end 
					   ,[check_description]=case when [check_description] like '%{JOB}%'
												then replace([check_description],'{JOB}',d.[job_name] collate database_default)
												else [check_description] end
					   ,[check_query]=replace(replace([check_query],'{JOB}',d.[job_name] collate database_default),'{SQL_INSTANCE}',@sql_instance)
					   ,[check_frequency_minutes]
					   ,[check_threshold_warning]
					   ,[check_threshold_critical]
					   ,[check_enabled]
					   ,[ignore_flapping]
					   ,[check_template_id]
					   ,[object_type] = @expand_by
					   ,[object_name] = d.[job_name]
					   ,@sql_instance
					   ,[use_baseline]
					from [dbo].[sqlwatch_config_check_template] c
					cross apply (
						select *, is_current=ROW_NUMBER() over (partition by job_name order by job_create_date desc)
						from [dbo].[vw_sqlwatch_report_dim_agent_job]
						where sql_instance = @sql_instance
						) d
					where c.check_name = @check_name
					and c.expand_by = @expand_by
					and d.is_current = 1
				end

			if @expand_by = 'Database'
				begin

					insert into @checks (
							[check_name],[check_description],[check_query],[check_frequency_minutes],[check_threshold_warning]
						   ,[check_threshold_critical],[check_enabled],[ignore_flapping],[check_template_id], [object_type], [object_name]
						   ,[target_sql_instance]
						   ,[use_baseline]
					)

					--this use to point to sys.databases hence the collate, I don't think we need collate anymore as within the db scope.
					select 
					   [check_name]=case 
								when c.check_name like '%{DATABASE}%' then replace(c.check_name,'{DATABASE}',d.[database_name] collate database_default) 
								else c.check_name + ' (' + d.[database_name] collate database_default + ')' end
					   ,[check_description]=case when [check_description] like '%{DATABASE}%'
												then replace([check_description],'{DATABASE}',d.[database_name] collate database_default)
												else [check_description] end
					   ,[check_query]=replace(replace([check_query],'{DATABASE}',d.[database_name] collate database_default),'{SQL_INSTANCE}',@sql_instance)
					   ,[check_frequency_minutes]
					   ,[check_threshold_warning]
					   ,[check_threshold_critical]
					   ,[check_enabled]
					   ,[ignore_flapping]
					   ,[check_template_id]
					   ,[object_type] = @expand_by
					   ,[object_name] = d.[database_name]
					   ,@sql_instance
					   ,[use_baseline]
					from [dbo].[sqlwatch_config_check_template] c
					cross apply (
						select *
						from [dbo].[sqlwatch_meta_database]
						where sql_instance = @sql_instance
						and is_current = 1
					) d
					where c.check_name = @check_name
					and c.expand_by = @expand_by
					and d.sql_instance = @sql_instance
				end

			fetch next from cur_expand_check 
				into @check_name, @expand_by, @check_template_id
		end

		close cur_expand_check
		deallocate cur_expand_check;

		fetch next from cur_expand_by_server
			into @sql_instance
	end

	close cur_expand_by_server
	deallocate cur_expand_by_server;

	;merge [dbo].[sqlwatch_config_check] as target 
	using @checks as source
	on target.check_name = source.check_name
	and target.[target_sql_instance] = source.[target_sql_instance]

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
				,[base_object_type]
				,[base_object_name]
				,[base_object_date_last_seen]
				,[target_sql_instance]
				,[use_baseline]
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
				,[object_type]
				,[object_name]
				,getutcdate()
				,[target_sql_instance]
				,[use_baseline]
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
				,[ignore_flapping] = source.[ignore_flapping]
				,[base_object_type] = source.[object_type]
				,[base_object_name] = source.[object_name]
				,[base_object_date_last_seen] = case when source.[object_name] is not null then getutcdate() else [base_object_date_last_seen] end
				,[use_baseline] = source.[use_baseline]
		;

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
		
			from [dbo].[sqlwatch_config_check] cc

			inner join [dbo].[sqlwatch_config_check_template]  ct
				on ct.check_template_id = cc.check_template_id

			inner join [dbo].[sqlwatch_config_check_template_action] a
				on a.check_name = ct.check_name
			
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
