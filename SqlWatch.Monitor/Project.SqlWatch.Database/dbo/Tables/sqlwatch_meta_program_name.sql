CREATE TABLE [dbo].[sqlwatch_meta_program_name]
(
	[program_name_id] smallint identity(1,1) not null,
	[program_name] nvarchar(128),
	[sql_instance] varchar(32),

	constraint pk_sqlwatch_meta_program_name 
		primary key clustered (
		  [program_name]
		, [sql_instance]
		),

	constraint fk_sqlwatch_meta_program_name_sql_instance 
		foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) 
		on delete cascade
);
go

create unique index idx_sqlwatch_meta_program_name_id 
	on [dbo].[sqlwatch_meta_program_name] ([program_name_id]);