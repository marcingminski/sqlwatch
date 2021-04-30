CREATE TABLE [dbo].[sqlwatch_meta_query_plan]
(
	[sql_instance] varchar(32) not null,
	[plan_handle] varbinary(64) not null,
	[statement_start_offset] int not null,
	[statement_end_offset] int not null,

	[sql_handle] varbinary(64) null,
	[query_hash] varbinary(8) not null,
	[query_plan_hash] varbinary(8) not null,

	sqlwatch_database_id smallint not null,
	sqlwatch_procedure_id int not null,

	--only save query plan and statement here if the query plan hash is null (in-memory OLTP)
	--otherwise we're only saving plans for each each hash which saves a lot of space
	[query_plan_for_plan_handle] nvarchar(max) null,
	[statement_for_plan_handle] varchar(max) null,

	[date_first_seen] datetime2(0) not null,
	[date_last_seen] datetime2(0) not null,

	constraint pk_sqlwatch_meta_query_plan_handle
		primary key (
		  	  sql_instance
			, [plan_handle]
			, [query_plan_hash]
			, [statement_start_offset]
			, [statement_end_offset]
			, sqlwatch_database_id
			, sqlwatch_procedure_id
			),

	constraint fk_sqlwatch_meta_query_plan_handle_procedure
		foreign key (sql_instance,[sqlwatch_database_id],sqlwatch_procedure_id)
		references dbo.sqlwatch_meta_procedure (sql_instance,[sqlwatch_database_id],sqlwatch_procedure_id) 
		on delete cascade
)
go

create trigger dbo.[trg_sqlwatch_meta_query_plan_handle_delete_text]
	on [dbo].[sqlwatch_meta_query_plan]
	after delete
	as
	begin
		set nocount on;

		--this trigger must delete query_plan_text but only if there are no more plan_handles left for that hash.
		--othewriwse, if we delete all handles we are going to have orphaned query_text as there is no relation between tables due to the fact that we changed PK
		delete t
		from dbo.[sqlwatch_meta_query_plan_hash] t
		where t.query_plan_hash not in (
			select query_plan_hash
			from dbo.[sqlwatch_meta_query_plan] 
		)

		;		

	end
go