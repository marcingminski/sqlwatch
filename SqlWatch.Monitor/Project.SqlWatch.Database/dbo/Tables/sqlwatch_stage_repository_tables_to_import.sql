CREATE TABLE [dbo].[sqlwatch_stage_repository_tables_to_import]
(
	[table_name] [nvarchar](512) not null primary key,
	[dependency_level] tinyint NULL,
	[has_last_seen] bit null,
	[has_last_updated] bit null,
	[has_identity] bit NULL,
	[primary_key] [nvarchar](max) NULL,
	[joins] [nvarchar](max) NULL,
	[updatecolumns] [nvarchar](max) NULL,
	[allcolumns] [nvarchar](max) NULL
);
