CREATE TABLE [dbo].[sqlwatch_logger_xes_wait_stat_event_query]
(
	event_time datetime not null,
	activity_id uniqueidentifier not null,
	activity_id_sequence bigint not null,
	session_id int,
	client_hostname varchar(255),
	client_app_name varchar(255),
	username varchar(255),
	query_hash decimal(20,0) not null,
	sql_text varchar(max),
	sql_statement varchar(max),
	sqlwatch_database_id smallint,
	sql_instance varchar(32) not null,
	snapshot_time datetime2(0) not null,
	snapshot_type_id tinyint not null,
	sqlwatch_sql_text_hash varbinary(16),

	constraint pk_sqlwatch_logger_xes_wait_stat_event_query 
		primary key clustered (
			  sql_instance
			, activity_id
			, activity_id_sequence
			, snapshot_time
			, snapshot_type_id
			, sqlwatch_sql_text_hash
			)
)
