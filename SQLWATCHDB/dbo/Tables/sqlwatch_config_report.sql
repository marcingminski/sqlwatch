CREATE TABLE [dbo].[sqlwatch_config_report]
(
	[report_id] smallint identity(1,1) not null,
	[report_title] varchar(255) not null,
	[report_description] varchar(4000) null,
	[report_definition] nvarchar(max) not null,
	[report_definition_type] varchar(25) not null constraint df_sqlwatch_config_report_type default ('HTML-Table'),
	[report_active] bit not null constraint df_sqlwatch_config_report_active default (1),
	[report_batch_id] varchar(255) null,
	[report_style_id] smallint null,
	[date_created] datetime constraint df_sqlwatch_config_report_date_created default (getdate()),
	[date_updated] datetime null,

	/*	primary key */
	constraint pk_sqlwatch_config_report primary key clustered ([report_id]),

	/*	check to only allow valid types 
		Template = gets passed right into sp_execute_sql and output passed to action.
		Table = (was Query) a SQL query that gets converted to HTML table and passed to action
		Query = a raw query that is not being processed but passed directly to action for further processing
	*/
	constraint chk_sqlwatch_config_report check ((
		   (
			   [report_definition_type]='Template' --old
			OR [report_definition_type]='HTML-Template'
			OR [report_definition_type]='Table' --old
			OR [report_definition_type]='HTML-Table'
			OR [report_definition_type]='Query'
			)
		/*	make sure we have style_id when report is not raw query */
		AND (  [report_style_id] IS NULL AND [report_definition_type] = 'Query'
			OR [report_style_id] IS NOT NULL AND [report_definition_type] <> 'Query'
			)
			
		)),

	/*	foreign key to report style to make sure we have valid report and to prevent 
		deleting styles if assosiated with report */
	constraint fk_sqlwatch_config_report_style foreign key ([report_style_id])
		references [dbo].[sqlwatch_config_report_style] ([report_style_id]) on delete no action,
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

create trigger dbo.trg_trg_sqlwatch_config_report_D
	on [dbo].[sqlwatch_config_report]
	for delete
	as
	begin
		set nocount on;
		delete l from [dbo].[sqlwatch_logger_report_action] l
		inner join deleted d
		on l.report_id = d.report_id
		and l.sql_instance = @@SERVERNAME
	end
go


create trigger dbo.trg_sqlwatch_config_report_meta_IU
	on [dbo].[sqlwatch_config_report]
	for insert, update
	as
	begin
		set nocount on;

		merge [dbo].[sqlwatch_meta_report]  as target
		using (
			select 
				  [sql_instance] = @@SERVERNAME
				, [report_id]
				, [report_title]
				, [report_description]
				, [report_definition]
				, [report_definition_type]
				, [report_batch_id]
				from inserted
				) as source
			on source.[report_id] = target.[report_id]
			and target.sql_instance = @@SERVERNAME

		when not matched then
			insert ([sql_instance], [report_id],[report_title],[report_description],[report_definition],[report_definition_type],[report_batch_id])
			values (
				 source.[sql_instance]
				,source.[report_id]
				,source.[report_title]
				,source.[report_description]
				,source.[report_definition]
				,source.[report_definition_type]
				,source.[report_batch_id]
				)

		when matched then
			update
				set  [sql_instance] = source.[sql_instance]
					,[report_id] = source.[report_id]
					,[report_title] = source.[report_title]
					,[report_description] = source.[report_description]
					,[report_definition] = source.[report_definition]
					,[report_definition_type] = source.[report_definition_type]
		;
	end
go

create trigger dbo.trg_sqlwatch_config_report_meta_D
	on [dbo].[sqlwatch_config_report]
	for delete
	as
	begin
		set nocount on;

		delete m from [dbo].[sqlwatch_meta_report] m
		inner join deleted d 
			on d.[report_id] = m.[report_id]
			and m.sql_instance = @@SERVERNAME
		left join inserted i
			on i.[report_id] = m.[report_id]
			and m.sql_instance = @@SERVERNAME
		where i.[report_id] is null
	end