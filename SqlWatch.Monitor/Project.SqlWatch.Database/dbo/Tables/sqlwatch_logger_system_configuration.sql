CREATE TABLE [dbo].[sqlwatch_logger_system_configuration]
(
	sql_instance varchar(32) not null default @@SERVERNAME,
	sqlwatch_configuration_id smallint not null,
	value int not null,
	value_in_use int not null,
	snapshot_time datetime2(0),
	snapshot_type_id tinyint default(26),
	constraint pk_sqlwatch_logger_system_configuration primary key clustered (
		sqlwatch_configuration_id, snapshot_time, snapshot_type_id
		),
	constraint fk_sqlwatch_logger_system_configuration_keyword foreign key (sql_instance, sqlwatch_configuration_id) 
		references dbo.sqlwatch_meta_system_configuration (sql_instance, sqlwatch_configuration_id)on delete cascade,
	constraint fk_sqlwatch_logger_system_configuration_snapshot foreign key ([snapshot_time], [sql_instance], [snapshot_type_id])
		references dbo.sqlwatch_logger_snapshot_header ([snapshot_time], [sql_instance], [snapshot_type_id]) on delete cascade
)
go