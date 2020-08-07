CREATE TABLE [dbo].[sqlwatch_config_wait_stats]
(
	[wait_type] nvarchar(60) not null,
	[wait_category] nvarchar(60) not null,
	[report_include] bit not null,
	constraint pk_sqlwatch_config_wait_stats primary key (
		[wait_type]
		)
)
