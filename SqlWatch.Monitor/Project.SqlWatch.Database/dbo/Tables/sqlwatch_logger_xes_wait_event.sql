CREATE TABLE [dbo].[sqlwatch_logger_xes_wait_event]
(
	event_time datetime not null,
	wait_type_id smallint not null,
	--activity_id uniqueidentifier not null,
	--activity_id_sequence bigint not null,
	duration bigint not null,
	signal_duration bigint not null,
	session_id int,
	username nvarchar(255),
	client_hostname nvarchar(255),
	client_app_name nvarchar(255),
	sqlwatch_database_id smallint,
	query_hash decimal(20,0) null,
	sqlwatch_query_plan_id int null,
	sqlwatch_query_id int,
	sql_instance varchar(32) not null,
	snapshot_time datetime2(0) not null,
	snapshot_type_id tinyint not null,
	
	constraint pk_sqlwatch_logger_xes_wait_stat_event primary key clustered (
		event_time, wait_type_id, session_id, [sql_instance], [snapshot_time], [snapshot_type_id] 
	),

	constraint fk_sqlwatch_logger_xes_wait_stat_event_snapshot_header foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) on delete cascade on update cascade,

	constraint fk_sqlwatch_logger_xes_wait_stat_event_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade

	/*	we're not doing foreign key to [dbo].[sqlwatch_meta_sql_query] as we want to be able to delete from sqlwatch_meta_sql_query if it gets too big
		without losing any of the wait information. */

)
