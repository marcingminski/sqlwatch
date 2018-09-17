CREATE TABLE [dbo].[sql_perf_mon_database]
(
	[database_name] sysname not null,
	[database_create_date] datetime not null default '1970-01-01',
	[database_current] bit not null default 1,
	constraint PK_database primary key clustered (
	 [database_name],[database_create_date]
	 )
)
GO
CREATE NONCLUSTERED INDEX idx_perf_mon_database_current ON [dbo].[sql_perf_mon_database]([database_current])
