ALTER TABLE [dbo].[sqlwatch_logger_errorlog]
	ADD CONSTRAINT [pk_sqlwatch_logger_errorlog]
	PRIMARY KEY CLUSTERED (snapshot_time, log_date, attribute_id, errorlog_text_id, keyword_id, log_type_id, snapshot_type_id)
	WITH (DATA_COMPRESSION=PAGE)
