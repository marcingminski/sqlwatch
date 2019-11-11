CREATE TABLE [dbo].[sqlwatch_config_report_style]
(
	[report_style_id] smallint identity(1,1) not null,
	[style] nvarchar(max) not null,
	constraint pk_sqlwatch_config_report_style primary key clustered (
		[report_style_id]
	)
)
