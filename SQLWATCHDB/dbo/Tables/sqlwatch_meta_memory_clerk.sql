CREATE TABLE [dbo].[sqlwatch_meta_memory_clerk]
(
	[sql_instance] varchar(32) not null constraint df_sqlwatch_meta_memory_clerk_sql_instance default (@@SERVERNAME),
	[sqlwatch_mem_clerk_id] smallint identity(1,1),
	[clerk_name] nvarchar(255) not null,
	constraint pk_sqlwatch_meta_memory_clerk primary key clustered (
		[sql_instance], [sqlwatch_mem_clerk_id]
		),
	constraint uq_sqlwatch_meta_memory_clerk unique (
		[sql_instance], [clerk_name]
		),
	constraint fk_sqlwatch_meta_memory_clerk_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
