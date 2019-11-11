CREATE TABLE [dbo].[sqlwatch_config_report]
(
	[sql_instance] varchar(32) not null default @@SERVERNAME,
	[report_id] smallint identity(1,1) not null,
	[report_title] varchar(255) not null,
	[report_description] varchar(4000) null,
	[report_definition] nvarchar(max) not null,
	[report_definition_type] varchar(10) not null default 'Query',
	[report_active] bit not null default 1,
	[report_batch_id] tinyint null,
	[report_style_id] smallint not null,
	constraint pk_sqlwatch_config_report primary key clustered (
		[sql_instance], [report_id]
	),
	constraint fk_sqlwatch_config_report_servername foreign key ([sql_instance])
		references dbo.sqlwatch_meta_server ([servername]) on delete cascade,
	constraint chk_sqlwatch_config_report check ([report_definition_type] in ('Query','Template')),
	constraint fk_sqlwatch_config_report_style foreign key ([report_style_id])
		references [dbo].[sqlwatch_config_report_style] ([report_style_id])
)
