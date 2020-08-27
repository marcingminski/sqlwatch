CREATE TABLE [dbo].[sqlwatch_meta_procedure]
(
	[sqlwatch_procedure_id] int identity(1,1) not null,
	[sql_instance] varchar(32) not null,
	[sqlwatch_database_id] smallint,
	[procedure_name] nvarchar(256) not null,
	[procedure_type] char(1) not null,
	[date_first_seen] datetime not null,
	[date_last_seen] datetime not null,

	constraint pk_sqlwatch_meta_procedure primary key clustered (
		[sql_instance], [sqlwatch_database_id], [sqlwatch_procedure_id]
	),
	 constraint fk_sqlwatch_meta_procedure_server foreign key ([sql_instance]) 
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
go

create unique nonclustered index idx_sqlwatch_meta_procedure_1 
	on [dbo].[sqlwatch_meta_procedure] ([sql_instance],[sqlwatch_database_id],[procedure_name])
	include ([date_last_seen],[sqlwatch_procedure_id])
	