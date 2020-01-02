CREATE TABLE [dbo].[sqlwatch_config_sql_instance]
(
	[sql_instance] varchar(32) not null constraint df_sqlwatch_config_sql_instance_sql_instance default (@@SERVERNAME),
	[hostname] nvarchar(32) null,
	[sql_port] smallint null,
	[sqlwatch_database_name] sysname not null constraint df_sqlwatch_config_sql_instance_database_name default (DB_NAME()),
	[environment] sysname not null constraint df_sqlwatch_config_sql_instance_env default ('DEFAULT'),
	[repo_collector_is_active] bit not null constraint df_sqlwatch_config_sql_instance default (1),
	[linked_server_name] nvarchar(255),
	constraint pk_config_sql_instance primary key clustered (
		[sql_instance]
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