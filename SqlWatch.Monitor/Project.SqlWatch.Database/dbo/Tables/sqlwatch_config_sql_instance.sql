CREATE TABLE [dbo].[sqlwatch_config_sql_instance]
(
	[sql_instance] varchar(32) not null constraint df_sqlwatch_config_sql_instance_sql_instance default (@@SERVERNAME),
	[hostname] nvarchar(32) null,
	[sql_port] int null,
	[sqlwatch_database_name] sysname not null constraint df_sqlwatch_config_sql_instance_database_name default (DB_NAME()),
	[environment] sysname not null constraint df_sqlwatch_config_sql_instance_env default ('DEFAULT'),
	[repo_collector_is_active] bit not null constraint df_sqlwatch_config_sql_instance default (1),
	[linked_server_name] nvarchar(255),
	[sql_instance_user_alias] nvarchar(128) null,
	[sql_user] varchar(50) NULL,
	[sql_secret] varchar(255) NULL,
	[integrated_security] bit not null constraint df_config_sql_instance_auth_default default (1),
	
	constraint pk_config_sql_instance primary key clustered (
		[sql_instance]
	)

	/*  [repo_collector_is_active] only applies to remote instances.
		we can pause collection by setting it to 0 and when set to 0 it will dissapear from PBI.
		However, we cannot set local collector to 1 as it would attempt to collect data from local instance resulting in clash.
		PBI will always show local collector as a minimum regardles this flag */
	
	--since SqlWatchCollect can collect data from the local instance, this is no longer relevant.
	--constraint chk_sqlwatch_config_sql_instance_is_active check (
	--	([sql_instance] = @@SERVERNAME and [repo_collector_is_active] = 0)
	--	or ([sql_instance] <> @@SERVERNAME and [repo_collector_is_active] in (1,0))
	--	)
);
go

create unique nonclustered index idx_sqlwatch_config_sql_instance_hostname_port 
	on [dbo].[sqlwatch_config_sql_instance] (hostname, sql_port) 
	where hostname is not null and sql_port is not null;
go

create unique nonclustered index idx_sqlwatch_config_sql_instance_hostname
	on [dbo].[sqlwatch_config_sql_instance] (hostname) 
	where hostname is not null and sql_port is null;
go

--create trigger dbo.trg_sqlwatch_config_sql_instance_central_repository
--	on [dbo].[sqlwatch_config_sql_instance]
--	after insert, delete
--	as
--	begin
--		set nocount on;
--		--more than one record in the sql_instance table assumes we're running central repository:
--		if (select count(*) from [dbo].[sqlwatch_config_sql_instance]) > 1
--			begin
--				--build the list of tables to import not already built:
--				if (select count(*) from [dbo].[sqlwatch_stage_repository_tables_to_import]) = 0
--					begin
--						exec [dbo].[usp_sqlwatch_repository_populate_tables_to_import]
--					end
--			end
--	end
--go

create trigger dbo.trg_sqlwatch_config_sql_instance_sanitise
	on [dbo].[sqlwatch_config_sql_instance]
	for insert, update
	as
	begin
		set nocount on;
		update t
			set t.[sql_instance] = rtrim(ltrim(replace(replace(replace(s.[sql_instance],char(10),''),char(13),''),'"','')))
		from inserted s 
		inner join [dbo].[sqlwatch_config_sql_instance] t
			on s.[sql_instance] = t.[sql_instance];
	end;
go

create trigger dbo.trg_sqlwatch_config_sql_instance_remove_meta
	on [dbo].[sqlwatch_config_sql_instance]
	instead of delete
	as
	begin
		set nocount on;

		declare @deleted_instance table (
			sql_instance varchar(32)
			);

		insert into @deleted_instance
		select sql_instance from deleted;

		-- first, disable the remote collection:
		update c
			set repo_collector_is_active = 0
		from [dbo].[sqlwatch_config_sql_instance] c
		inner join @deleted_instance d
			on c.sql_instance = d.sql_instance;

		-- delete each server, leverage cascade deletes:
		delete from dbo.sqlwatch_meta_server
		where servername in (
			select sql_instance from @deleted_instance
			);

		-- finally, delete from the config table:
		delete from [dbo].[sqlwatch_config_sql_instance]
		where sql_instance in (
			select sql_instance from @deleted_instance
			);
	end;
