CREATE TABLE [dbo].[sqlwatch_meta_wait_stats]
(
	[sql_instance] varchar(32) not null,
	[wait_type] nvarchar(60) not null, 
	[wait_type_id] smallint identity(1,1) not null,
	constraint pk_sqlwatch_meta_wait_stats primary key (
		[sql_instance], [wait_type_id]
		),
	constraint uq_sqlwatch_meta_wait_stats_wait_type unique ([sql_instance],[wait_type]),
	constraint fk_sqlwatch_meta_wait_stats_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
