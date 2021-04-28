CREATE TABLE [dbo].[sqlwatch_meta_procedure_query_plan]
(
	sql_instance varchar(32) not null,
	[sqlwatch_procedure_id] int not null,
	[sqlwatch_database_id] smallint not null,
	[sqlwatch_query_plan_id] int not null,
	[date_updated] datetime2(0) not null,

	constraint pk_sqlwatch_meta_query_plan_procedure
		primary key clustered (
			sql_instance, [sqlwatch_procedure_id], [sqlwatch_query_plan_id]
			),

	constraint fk_sqlwatch_meta_procedure_query_plan_procedure 
		foreign key (sql_instance, [sqlwatch_database_id], [sqlwatch_procedure_id])
		references [dbo].[sqlwatch_meta_procedure] ([sql_instance], [sqlwatch_database_id], [sqlwatch_procedure_id])
		on delete cascade
)
