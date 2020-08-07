CREATE TABLE [dbo].[sqlwatch_logger_errorlog]
(
	sql_instance varchar(32) not null default @@SERVERNAME,
	log_date datetime,
	attribute_id smallint,
	errorlog_text_id int,
	keyword_id smallint,
	log_type_id int,
	snapshot_time datetime2(0),
	snapshot_type_id tinyint,
	constraint pk_sqlwatch_logger_errorlog primary key clustered (
		snapshot_time, log_date, attribute_id, errorlog_text_id, keyword_id, log_type_id, snapshot_type_id
		),
	constraint fk_sqlwatch_logger_errorlog_keyword foreign key (sql_instance, keyword_id, log_type_id) 
		references dbo.sqlwatch_meta_errorlog_keyword (sql_instance, keyword_id, log_type_id) on delete cascade,

	constraint fk_sqlwatch_logger_errorlog_snapshot foreign key ([snapshot_time], [sql_instance], [snapshot_type_id])
		references dbo.sqlwatch_logger_snapshot_header ([snapshot_time], [sql_instance], [snapshot_type_id]) on delete cascade
)
go

create nonclustered index idx_sqlwatch_logger_errorlog_1 on [dbo].[sqlwatch_logger_errorlog] (
	keyword_id, log_type_id, sql_instance
	) include (log_date)