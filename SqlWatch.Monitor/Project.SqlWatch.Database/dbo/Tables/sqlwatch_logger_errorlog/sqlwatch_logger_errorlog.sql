CREATE TABLE [dbo].[sqlwatch_logger_errorlog]
(
	sql_instance varchar(32) not null default @@SERVERNAME,
	log_date datetime not null,
	attribute_id smallint not null,
	errorlog_text_id int not null,
	keyword_id smallint not null,
	log_type_id int not null,
	snapshot_time datetime2(0) not null,
	snapshot_type_id tinyint not null,
	record_count real --there could be many entries of the same type at the same time in the error log (especially failed logins)

	constraint fk_sqlwatch_logger_errorlog_keyword foreign key (sql_instance, keyword_id, log_type_id) 
		references dbo.sqlwatch_meta_errorlog_keyword (sql_instance, keyword_id, log_type_id) on delete cascade,

	constraint fk_sqlwatch_logger_errorlog_snapshot foreign key ([snapshot_time], [sql_instance], [snapshot_type_id])
		references dbo.sqlwatch_logger_snapshot_header ([snapshot_time], [sql_instance], [snapshot_type_id]) on delete cascade
);
go