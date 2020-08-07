CREATE TABLE [dbo].[sqlwatch_meta_report]
(
	[sql_instance] varchar(32) not null,
	[report_id] smallint not null,
	[report_title] varchar(255) not null,
	[report_description] varchar(4000) null,
	[report_definition] nvarchar(max) not null,
	[report_definition_type] varchar(25) not null,
	[report_last_run_date] datetime null,
	[report_batch_id] varchar(255) null,
	constraint pk_sqlwatch_meta_report primary key (
		[sql_instance], [report_id]
	),
	constraint fk_sqlwatch_meta_report_server foreign key ([sql_instance])
		references dbo.sqlwatch_meta_server ([servername]) on delete cascade
)
go
