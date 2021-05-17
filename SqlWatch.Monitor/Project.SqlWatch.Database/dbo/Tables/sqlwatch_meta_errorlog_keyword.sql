CREATE TABLE [dbo].[sqlwatch_meta_errorlog_keyword]
(
	sql_instance varchar(32) not null,
	keyword_id smallint not null,-- identity(1,1) ,
	log_type_id int not null,
	keyword1 nvarchar(255),
	keyword2 nvarchar(255),
	[date_updated] datetime not null constraint df_sqlwatch_meta_errorlog_keyword_updated default (getutcdate()),
	constraint pk_sqlwatch_meta_errorlog_keyword primary key clustered (
		sql_instance, keyword_id, log_type_id
		),
	constraint fk_sqlwatch_meta_errorlog_keyword_server foreign key (sql_instance) 
		references dbo.sqlwatch_meta_server (servername) on delete cascade
)
go

create nonclustered index idx_sqlwatch_meta_errorlog_keyword_1 on [dbo].[sqlwatch_meta_errorlog_keyword] (keyword1)
	include (sql_instance, keyword_id, log_type_id)
go

create nonclustered index idx_sqlwatch_meta_errorlog_keyword_2 on [dbo].[sqlwatch_meta_errorlog_keyword] ([date_updated])
go

create trigger trg_sqlwatch_meta_errorlog_keyword_last_updated
	on [dbo].[sqlwatch_meta_errorlog_keyword]
	for insert,update
	as
	begin
		set nocount on;
		set xact_abort on;

		update t
			set date_updated = getutcdate()
		from [dbo].[sqlwatch_meta_errorlog_keyword] t
		inner join inserted i
			on i.sql_instance = t.sql_instance
			and i.keyword_id = t.keyword_id
			and i.log_type_id = t.log_type_id
			and i.sql_instance = @@SERVERNAME
	end
go