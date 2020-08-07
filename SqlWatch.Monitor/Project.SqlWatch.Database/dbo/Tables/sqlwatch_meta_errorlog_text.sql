CREATE TABLE [dbo].[sqlwatch_meta_errorlog_text]
(
	sql_instance varchar(32) default @@SERVERNAME,
	errorlog_text_id int identity(1,1),
	errorlog_text nvarchar(max),
	total_occurence_count int,
	first_occurence datetime,
	last_occurence datetime,
	constraint pk_sqlwatch_meta_errorlog_text primary key clustered (
		sql_instance, errorlog_text_id
		),
	constraint fk_sqlwatch_meta_errorlog_text_server foreign key (sql_instance)
		references dbo.sqlwatch_meta_server (servername) on delete cascade
)
