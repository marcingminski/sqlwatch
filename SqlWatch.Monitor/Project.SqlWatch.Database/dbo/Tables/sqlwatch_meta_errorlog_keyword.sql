CREATE TABLE [dbo].[sqlwatch_meta_errorlog_keyword]
(
	sql_instance varchar(32) not null,
	keyword_id smallint identity(1,1) not null,
	log_type_id int not null,
	keyword nvarchar(255),
	constraint pk_sqlwatch_meta_errorlog_keyword primary key clustered (
		sql_instance, keyword_id, log_type_id
		),
	constraint fk_sqlwatch_meta_errorlog_keyword_server foreign key (sql_instance) 
		references dbo.sqlwatch_meta_server (servername) on delete cascade
)
go

create nonclustered index idx_sqlwatch_meta_errorlog_keyword_1 on [dbo].[sqlwatch_meta_errorlog_keyword] (keyword)
	include (sql_instance, keyword_id, log_type_id)