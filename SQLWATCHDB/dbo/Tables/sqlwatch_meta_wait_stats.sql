CREATE TABLE [dbo].[sqlwatch_meta_wait_stats]
(
	[sql_instance] nvarchar(25) not null,
	[wait_type] nvarchar(60) not null, 
	[wait_type_id] uniqueidentifier not null default newsequentialid(),
	constraint pk_sqlwatch_meta_wait_stats primary key (
		[sql_instance], [wait_type_id]
		),
	constraint uq_sqlwatch_meta_wait_stats_wait_type unique ([sql_instance],[wait_type])
)
