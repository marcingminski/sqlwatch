CREATE TABLE [dbo].[sqlwatch_meta_errorlog_text]
(
	sql_instance varchar(32) default @@SERVERNAME,
	errorlog_text_id int identity(1,1),
	errorlog_text nvarchar(max),
	total_occurence_count int,
	--these should be called first_seen and last_seen. change in v5.
	first_occurence datetime,
	last_occurence datetime,
	[date_updated] datetime not null constraint df_sqlwatch_meta_errorlog_text_updated default (getutcdate()),
	constraint pk_sqlwatch_meta_errorlog_text primary key clustered (
		sql_instance, errorlog_text_id
		),
	constraint fk_sqlwatch_meta_errorlog_text_server foreign key (sql_instance)
		references dbo.sqlwatch_meta_server (servername) on delete cascade
)
go

create nonclustered index idx_sqlwatch_meta_errorlog_text_1 on [dbo].[sqlwatch_meta_errorlog_text] ([date_updated])
go

create trigger trg_sqlwatch_meta_errorlog_text_last_updated
	on [dbo].[sqlwatch_meta_errorlog_text]
	for insert,update
	as
	begin
		set nocount on;

		update t
			set date_updated = getutcdate()
		from [dbo].[sqlwatch_meta_errorlog_text] t
		inner join inserted i
			on i.sql_instance = t.sql_instance
			and i.errorlog_text_id = t.errorlog_text_id
			and i.sql_instance = @@SERVERNAME
	end
go