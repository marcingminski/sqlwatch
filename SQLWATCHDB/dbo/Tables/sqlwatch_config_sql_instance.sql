CREATE TABLE [dbo].[sqlwatch_config_sql_instance]
(
	[sql_instance] varchar(32) not null constraint df_sqlwatch_config_sql_instance_sql_instance default (@@SERVERNAME),
	[hostname] nvarchar(32) null,
	[sql_port] int null,
	[sqlwatch_database_name] sysname not null constraint df_sqlwatch_config_sql_instance_database_name default (DB_NAME()),
	[environment] sysname not null constraint df_sqlwatch_config_sql_instance_env default ('DEFAULT'),
	[repo_collector_is_active] bit not null constraint df_sqlwatch_config_sql_instance default (1),
	[linked_server_name] nvarchar(255),
	constraint pk_config_sql_instance primary key clustered (
		[sql_instance]
	),
	/*  [repo_collector_is_active] only applies to remote instances.
		we can pause collection by setting it to 0 and when set to 0 it will dissapear from PBI.
		However, we cannot set local collector to 1 as it would attempt to collect data from local instance resulting in clash.
		PBI will always show local collector as a minimum regardles this flag */
	constraint chk_sqlwatch_config_sql_instance_is_active check (
		([sql_instance] = @@SERVERNAME and [repo_collector_is_active] = 0)
		or ([sql_instance] <> @@SERVERNAME and [repo_collector_is_active] in (1,0))
		)
)
go

create trigger dbo.trg_sqlwatch_config_sql_instance_remove_meta
	on [dbo].[sqlwatch_config_sql_instance]
	for delete
	as
	begin
		declare @deleted_instance table (
			sql_instance varchar(32)
			)

		insert into @deleted_instance
		select sql_instance from deleted

		set nocount on
		delete from dbo.sqlwatch_meta_server
		where servername in (
			select sql_instance from @deleted_instance
			)
	end
