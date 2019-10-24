CREATE TABLE [dbo].[sqlwatch_meta_database]
(
	[database_name] nvarchar(128) not null,
	[database_create_date] datetime not null default '1970-01-01',
	[sql_instance] varchar(32) not null default @@SERVERNAME,
	[sqlwatch_database_id] smallint identity(1,1),
	[deleted_when] datetime null,
	constraint PK_database primary key clustered (
		[sql_instance], [sqlwatch_database_id]
	 ),
	 constraint uq_sqlwatch_meta_database unique (
		[sql_instance], [database_name], [database_create_date]
	 ),
	 constraint fk_sqlwatch_meta_database_server foreign key ([sql_instance]) 
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
	 /* this will cause indefinite lock whilst checking constraints during load as the config_sql_instance will be locked by dequeing transcation, 
	    besides, we want to be able to remove server config from central repository without impacting data integrity. config tables should have no bearing on actual data tables */
	 --, constraint fk_database_server foreign key ([sql_instance]) references dbo.sqlwatch_config_sql_instance([sql_instance]) on delete cascade on update cascade
)
GO
--CREATE NONCLUSTERED INDEX idx_perf_mon_database_current ON [dbo].[sqlwatch_meta_database]([database_current])
