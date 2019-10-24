create table [dbo].[sqlwatch_meta_performance_counter]
(
	[sql_instance] varchar(32) not null,
	[object_name] nvarchar(128) not null,
	[counter_name] nvarchar(128) not null,
	[cntr_type] int not null,
	[performance_counter_id] smallint identity(1,1),
	constraint pk_sqlwatch_meta_performance_counter primary key (
		[sql_instance], [performance_counter_id]
		),
	constraint uq_sqlwatch_meta_performance_counter_object unique ([sql_instance], [object_name], [counter_name]),
	constraint fk_sqlwatch_meta_performance_counter_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
