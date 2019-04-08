CREATE TABLE [dbo].[sqlwatch_meta_database]
(
	[database_name] sysname not null,
	[database_create_date] datetime not null default '1970-01-01',
	[database_current] bit not null default 1,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME
	constraint PK_database primary key clustered (
	 [database_name],[database_create_date], [sql_instance]
	 ),
	 constraint fk_database_server foreign key ([sql_instance]) references dbo.sqlwatch_config_sql_instance([sql_instance]) on delete cascade
)
GO
CREATE NONCLUSTERED INDEX idx_perf_mon_database_current ON [dbo].[sqlwatch_meta_database]([database_current])
