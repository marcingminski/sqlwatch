CREATE TABLE [dbo].[sqlwatch_stage_meta_table]
(
	[TABLE_CATALOG] [nvarchar](128) not null,
	[TABLE_TYPE] [varchar](10) not null,
	[TABLE_NAME] nvarchar(512) not null,
	[sql_instance] varchar(32) not null,
	[database_create_date] datetime2(3),

	constraint pk_sqlwatch_stage_meta_table primary key clustered (
		[sql_instance], [TABLE_CATALOG], [TABLE_NAME], [database_create_date]
		)
)
