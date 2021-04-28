CREATE TABLE [dbo].[sqlwatch_meta_query_plan]
(
	[sqlwatch_query_plan_id] int identity(1,1) not null,
	[sql_instance] varchar(32) not null,
	--[plan_handle] varbinary(64) not null,
	--[sql_handle] varbinary(64) not null,
	[query_hash] varbinary(8) not null, --constraint df_sqlwatch_meta_query_plan_query_hash default 0x00000000,
	[query_plan_hash] varbinary(8) not null, --constraint df_sqlwatch_meta_query_plan_query_plan_hash default 0x00000000,
	[query_plan] nvarchar(max) null,
	--[statement_start_offset] int null,
	--[statement_end_offset] int null,
	[statement] varchar(max) null,
	--[sqlwatch_procedure_id] int not null constraint df_sqlwatch_meta_query_plan_procedure_id default -1,
	--procedure id would implicitly tell us which databsae it ran but we may not have procedure_id but still want to capture the plan and the database it ran in
	--not ideal from normalisation point of view but life is not always ideal too.
	--[sqlwatch_database_id] smallint not null, 
	[date_first_seen] datetime,
	[date_last_seen] datetime,

	--single query can have multiple plans
	constraint pk_sqlwatch_meta_plan_handle primary key clustered (
		sql_instance, sqlwatch_query_plan_id
	),

	constraint fk_sqlwatch_meta_plan_servername 
		foreign key ([sql_instance])
		references dbo.sqlwatch_meta_server ([servername]) on delete cascade

	/* we may have similar queries across different databases which may generete the same plan.
	   if we add sqlwatch_database_id to this table, we may be getting essentially the same plans but in different databses which may inflate the table 
	   to link plan with different datasbase we are going to need another table */
	--constraint fk_sqlwatch_meta_plan_database
	--	foreign key (sql_instance, [sqlwatch_database_id])
	--	references dbo.sqlwatch_meta_database (sql_instance, [sqlwatch_database_id])
)
go

create unique nonclustered index idx_sqlwatch_meta_query_plan_1
	on [dbo].[sqlwatch_meta_query_plan] (sql_instance, [query_hash], [query_plan_hash])
go

create trigger dbo.trg_sqlwatch_meta_query_plan_D
	on [dbo].[sqlwatch_meta_query_plan]
	after delete
	as
	begin
		set nocount on;
		-- when plans are deleted, remove records that link this plan to a procedure:
		delete t
		from [dbo].[sqlwatch_meta_procedure_query_plan]  t
		
		inner join [dbo].[sqlwatch_meta_query_plan_database] qpdb
			on qpdb.sql_instance = t.sql_instance
			and qpdb.sqlwatch_query_plan_id = t.sqlwatch_query_plan_id
			and qpdb.sqlwatch_database_id = t.sqlwatch_database_id

		inner join deleted d
			on d.sql_instance = t.sql_instance
			and d.sqlwatch_query_plan_id = qpdb.sqlwatch_query_plan_id

		-- and any records that link this plan to a database:
		delete t
		from [dbo].[sqlwatch_meta_query_plan_database] t
		inner join deleted d
			on d.sql_instance = t.sql_instance
			and d.sqlwatch_query_plan_id = t.sqlwatch_query_plan_id;

	end
go