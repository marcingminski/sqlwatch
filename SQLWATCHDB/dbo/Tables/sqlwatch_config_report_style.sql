CREATE TABLE [dbo].[sqlwatch_config_report_style]
(
	[report_style_id] smallint identity(1,1) not null,
	[style] nvarchar(max) not null,
	[date_created] datetime not null constraint df_sqlwatch_config_report_style_date_created default (getdate()),
	[date_updated] datetime null,
	constraint pk_sqlwatch_config_report_style primary key clustered (
		[report_style_id]
	)
)
go

create trigger dbo.trg_sqlwatch_config_report_style_updated_U
	on [dbo].[sqlwatch_config_report_style]
	for update
	as
	begin
		set nocount on;
		update t
			set date_updated = getdate()
		from [dbo].[sqlwatch_config_report_style] t
		inner join inserted i
		on i.[report_style_id] = t.[report_style_id]
	end
go
