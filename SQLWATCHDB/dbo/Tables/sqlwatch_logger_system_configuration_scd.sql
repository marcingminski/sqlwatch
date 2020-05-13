CREATE TABLE [dbo].[sqlwatch_logger_system_configuration_scd]
(
	sql_instance varchar(32) not null default @@SERVERNAME,
	sqlwatch_configuration_id smallint not null,
	value int not null,
	value_in_use int not null,
	valid_from datetime not null constraint sqlwatch_logger_system_configuration_scd_valid_from default(getutcdate()),
	valid_until datetime null,
	constraint pk_sqlwatch_logger_system_configuration_scd primary key clustered (
		sqlwatch_configuration_id, sql_instance, valid_from
		),
	constraint fk_sqlwatch_logger_system_configuration_scd_keyword foreign key (sql_instance, sqlwatch_configuration_id) 
		references dbo.sqlwatch_meta_system_configuration (sql_instance, sqlwatch_configuration_id)on delete cascade
)
go