CREATE TABLE [dbo].[sqlwatch_config_report]
(
	[report_id] smallint identity(1,1) not null,
	[report_title] varchar(255) not null,
	[report_description] varchar(4000) null,
	[report_definition] nvarchar(max) not null,
	[report_definition_type] varchar(10) not null constraint df_sqlwatch_config_report_type default ('Query'),
	[report_active] bit not null constraint df_sqlwatch_config_report_active default (1),
	[report_batch_id] tinyint null,
	[report_style_id] smallint not null,
	[date_created] datetime constraint df_sqlwatch_config_report_date_created default (getdate()),
	[date_updated] datetime null,

	/*	primary key */
	constraint pk_sqlwatch_config_report primary key clustered ([report_id]),

	/*	check to only allow valid types */
	constraint chk_sqlwatch_config_report check (([report_definition_type]='Template' OR [report_definition_type]='Query')),

	/*	foreign key to report style to make sure we have valid report and to prevent 
		deleting styles if assosiated with report */
	constraint fk_sqlwatch_config_report_style foreign key ([report_style_id])
		references [dbo].[sqlwatch_config_report_style] ([report_style_id]) on delete no action
)
go

create trigger dbo.trg_sqlwatch_config_report_updated_U
	on [dbo].[sqlwatch_config_report]
	for update
	as
	begin
		set nocount on;
		update t
			set date_updated = getdate()
		from [dbo].[sqlwatch_config_report] t
		inner join inserted i
			on i.[report_id] = t.[report_id]
	end
go