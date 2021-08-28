CREATE TABLE [dbo].[sqlwatch_meta_sql_query]
(
	[sql_instance] varchar(32) NOT NULL,
	[query_hash] varbinary(8) not null,
	[sql_statement_sample] nvarchar(max),
	[date_first_seen] datetime not null,
	[date_last_seen] datetime not null,
	--to calculate delta between snapshots, we need to know the last capture time for each query
	--rather than just "previous" snapshot_time as the query may not have been in the last snapshot
	last_usage_stats_snapshot_time datetime2(0),
	[sqlwatch_procedure_id] int,
	[sqlwatch_database_id] smallint,
	times_seen int,

	constraint pk_sqlwatch_meta_sql_text 
		primary key clustered ([sql_instance], [query_hash], [sqlwatch_database_id], [sqlwatch_procedure_id]),

	constraint fk_sqlwatch_meta_sql_text_procedure 
		foreign key (sql_instance, sqlwatch_database_id, sqlwatch_procedure_id) 
		references dbo.sqlwatch_meta_procedure (sql_instance, sqlwatch_database_id, sqlwatch_procedure_id) 
		on delete cascade
);
go