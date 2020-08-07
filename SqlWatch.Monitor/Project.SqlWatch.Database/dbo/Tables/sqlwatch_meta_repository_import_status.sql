CREATE TABLE [dbo].[sqlwatch_meta_repository_import_status]
(
	[sql_instance] varchar(32) not null,
	[object_name] nvarchar(512) not null,
	[import_status] varchar(50),
	[import_end_time] datetime2(7),
	[exec_proc] nvarchar(1024),
	[import_age_minutes] as datediff(minute,[import_end_time],getdate())
	constraint pk_sqlwatch_logger_repository_import primary key clustered (
		[sql_instance], [object_name]
	)
	-- https://github.com/marcingminski/sqlwatch/issues/153
	--,constraint fk_sqlwatch_logger_repository_import_status_server foreign key (sql_instance)
	--	references dbo.sqlwatch_meta_server (servername) on delete cascade
)
