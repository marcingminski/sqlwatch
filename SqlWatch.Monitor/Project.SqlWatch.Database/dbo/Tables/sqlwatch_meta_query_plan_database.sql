CREATE TABLE [dbo].[sqlwatch_meta_query_plan_database]
(
	[sql_instance] varchar(32) not null,
	[sqlwatch_query_plan_id] int not null,
	[sqlwatch_database_id] smallint not null,
	[date_updated] datetime2(0) not null,

	constraint pk_sqlwatch_meta_query_plan_database
		primary key clustered ([sql_instance] , [sqlwatch_query_plan_id] , [sqlwatch_database_id]),
	
	constraint fk_sqlwatch_meta_query_plan_database
		foreign key ([sql_instance], [sqlwatch_database_id])
		references dbo.sqlwatch_meta_database ([sql_instance], [sqlwatch_database_id])
		on delete cascade,

	--this would prevent deleting plans which we do not want
	--we are going to have to maintain deletions in this table via trigger
	--when plans are deleted a trigger will delete records from this table
	--constraint fk_sqlwatch_meta_query_plan_database_plan
	--	foreign key ([sql_instance] , [sqlwatch_query_plan_id])
	--	references dbo.sqlwatch_meta_query_plan ([sql_instance] , [sqlwatch_query_plan_id])
	--	on delete no action
)
