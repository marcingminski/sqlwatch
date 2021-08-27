CREATE TABLE [dbo].[sqlwatch_meta_sql_query_plan]
(
	[sql_instance] varchar(32) NOT NULL,
	[query_hash] varbinary(8) not null,
	[query_plan_hash] varbinary(8) not null,
	[query_plan_sample] nvarchar(max),
	[date_first_seen] datetime not null,
	[date_last_seen] datetime not null,
	last_usage_stats_snapshot_time datetime2(0),
	[sqlwatch_procedure_id] int,
	[sqlwatch_database_id] smallint,
	times_seen int,

	constraint pk_sqlwatch_meta_sql_query_plan 
		primary key clustered (sql_instance, query_hash, query_plan_hash, sqlwatch_database_id, sqlwatch_procedure_id),

	constraint fk_sqlwatch_meta_sql_sql_query
		foreign key ([sql_instance], [query_hash], [sqlwatch_database_id], [sqlwatch_procedure_id])
		references dbo.sqlwatch_meta_sql_query ([sql_instance], [query_hash], [sqlwatch_database_id], [sqlwatch_procedure_id])
		on delete cascade
)