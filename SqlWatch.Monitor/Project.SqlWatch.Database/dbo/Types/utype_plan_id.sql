CREATE TYPE [dbo].[utype_plan_id] AS TABLE
(
	[sqlwatch_query_plan_id] int not null,
	[query_hash] varbinary(8) not null ,
	[query_plan_hash] varbinary(8) not null ,
	[action] varchar(50)
);
