CREATE TABLE [dbo].[sqlwatch_config_include_errorlog_keywords]
(
	keyword nvarchar(255),
	log_type_id int,
	constraint pk_sqlwatch_config_include_errorlog_keywords primary key clustered (
		keyword, log_type_id
		)
)
