CREATE TABLE [dbo].[sqlwatch_meta_system_configuration_scd]
(
	sql_instance varchar(32) not null default @@SERVERNAME,
	sqlwatch_configuration_id int not null,
	value int not null,
	value_in_use int not null,
	valid_from datetime not null constraint sqlwatch_logger_system_configuration_scd_valid_from default(getutcdate()),
	valid_until datetime null,
	[date_updated] datetime not null constraint df_sqlwatch_meta_system_configuration_scd_updated default (getutcdate()),
	constraint pk_sqlwatch_logger_system_configuration_scd primary key clustered (
		sqlwatch_configuration_id, sql_instance, valid_from
		),
	constraint fk_sqlwatch_logger_system_configuration_scd_keyword foreign key (sql_instance, sqlwatch_configuration_id) 
		references dbo.sqlwatch_meta_system_configuration (sql_instance, sqlwatch_configuration_id)on delete cascade
)
go

create nonclustered index idx_sqlwatch_meta_system_configuration_scd_1 on [dbo].[sqlwatch_meta_system_configuration_scd] ([date_updated])
go

create trigger trg_sqlwatch_meta_system_configuration_scd_last_updated
	on [dbo].[sqlwatch_meta_system_configuration_scd]
	for insert,update
	as
	begin
		set nocount on;

		update t
			set date_updated = getutcdate()
		from [dbo].[sqlwatch_meta_system_configuration_scd] t
		inner join inserted i
			on i.sqlwatch_configuration_id = t.sqlwatch_configuration_id
			and i.sql_instance = t.sql_instance
			and i.valid_from = t.valid_from
			and i.sql_instance = @@SERVERNAME
	end
go