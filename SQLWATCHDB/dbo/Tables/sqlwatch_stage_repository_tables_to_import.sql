CREATE TABLE [dbo].[sqlwatch_stage_repository_tables_to_import]
(
	[table_name] [nvarchar](512) not null primary key,
	[dependency_level] [int] NULL,
	[has_last_seen] [int] NULL,
	[primary_key] [nvarchar](max) NULL,
	[has_identity] [int] NULL,
	[joins] [nvarchar](max) NULL,
	[updatecolumns] [nvarchar](max) NULL,
	[allcolumns] [nvarchar](max) NULL
)
