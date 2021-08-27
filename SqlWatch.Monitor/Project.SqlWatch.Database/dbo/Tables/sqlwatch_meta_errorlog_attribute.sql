CREATE TABLE [dbo].[sqlwatch_meta_errorlog_attribute]
(
	sql_instance varchar(32) default @@SERVERNAME,
	attribute_id smallint identity(1,1),
	attribute_name varchar(255), 
	attribute_value varchar(255),
	[date_updated] datetime not null constraint df_sqlwatch_meta_errorlog_attribute_updated default (getutcdate()),
	constraint pk_sqlwatch_meta_errorlog_attributes primary key clustered (
		sql_instance, attribute_id
		),
	constraint fk_sqlwatch_meta_errorlog_attributes_server foreign key (sql_instance)
		references dbo.sqlwatch_meta_server (servername) on delete cascade
)
go

create nonclustered index idx_sqlwatch_meta_errorlog_attribute_1 on [dbo].[sqlwatch_meta_errorlog_attribute] ([date_updated])
go

create trigger trg_sqlwatch_meta_errorlog_attribute_last_updated
	on [dbo].[sqlwatch_meta_errorlog_attribute]
	for insert,update
	as
	begin
		set nocount on;

		update t
			set date_updated = getutcdate()
		from [dbo].[sqlwatch_meta_errorlog_attribute] t
		inner join inserted i
			on i.sql_instance = t.sql_instance
			and i.attribute_id = t.attribute_id
			and i.sql_instance = @@SERVERNAME
	end
go