CREATE TABLE [dbo].[sqlwatch_meta_database]
(
	[database_name] sysname not null,
	[database_create_date] datetime not null default '1970-01-01',
	[database_current] bit not null default 1,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME
	constraint PK_database primary key clustered (
	 [database_name],[database_create_date], [sql_instance]
	 )
	 /* this will cause indefinite lock whilst checking constraints during load as the config_sql_instance will be locked by dequeing transcation, 
	    besides, we want to be able to remove server config from central repository without impacting data integrity. config tables should have no bearing on actual data tables */
	 --, constraint fk_database_server foreign key ([sql_instance]) references dbo.sqlwatch_config_sql_instance([sql_instance]) on delete cascade on update cascade
)
GO
CREATE NONCLUSTERED INDEX idx_perf_mon_database_current ON [dbo].[sqlwatch_meta_database]([database_current])
