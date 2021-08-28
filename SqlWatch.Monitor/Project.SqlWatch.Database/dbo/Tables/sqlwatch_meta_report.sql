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
	[date_updated] datetime not null constraint df_sqlwatch_meta_report_updated default (getutcdate()),
	constraint pk_sqlwatch_meta_report primary key (
		[sql_instance], [report_id]
	),
	constraint fk_sqlwatch_meta_report_server foreign key ([sql_instance])
		references dbo.sqlwatch_meta_server ([servername]) on delete cascade
);
go

create nonclustered index idx_sqlwatch_meta_report_1 on [dbo].[sqlwatch_meta_report] ([date_updated]);
go

create trigger trg_sqlwatch_meta_report_last_updated
	on [dbo].[sqlwatch_meta_report]
	for insert,update
	as
	begin
		set nocount on;

		update t
			set date_updated = getutcdate()
		from [dbo].[sqlwatch_meta_report] t
		inner join inserted i
			on i.[sql_instance] = t.[sql_instance]
			and i.[report_id] = t.[report_id]
			and i.sql_instance = @@SERVERNAME;
	end;
go