CREATE TABLE [dbo].[sqlwatch_meta_errorlog_attribute]
(
	sql_instance varchar(32) default @@SERVERNAME,
	attribute_id smallint identity(1,1),
	attribute_name varchar(255), 
	attribute_value varchar(255),
	constraint pk_sqlwatch_meta_errorlog_attributes primary key clustered (
		sql_instance, attribute_id
		),
	constraint fk_sqlwatch_meta_errorlog_attributes_server foreign key (sql_instance)
		references dbo.sqlwatch_meta_server (servername) on delete cascade
)
