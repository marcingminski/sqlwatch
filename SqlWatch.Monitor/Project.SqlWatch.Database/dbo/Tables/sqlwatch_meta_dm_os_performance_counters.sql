create table [dbo].[sqlwatch_meta_dm_os_performance_counters]
(
	[sql_instance] varchar(32) not null,
	[object_name] nvarchar(128) not null,
	[counter_name] nvarchar(128) not null,
	[cntr_type] int not null,
	[performance_counter_id] int identity(1,1),
	[date_updated] datetime not null constraint df_sqlwatch_meta_performance_counter_updated default (getutcdate()),
	[is_sql_counter] bit --1 for counters in dmv, -- for OS counters via CLR, this will be automatically set. if a counter exists in DMV it will be used over CLR

	constraint pk_sqlwatch_meta_performance_counter primary key (
		[sql_instance], [performance_counter_id]
		),
	constraint uq_sqlwatch_meta_performance_counter_object unique ([sql_instance], [object_name], [counter_name]),
	constraint fk_sqlwatch_meta_performance_counter_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
go

create nonclustered index idx_sqlwatch_meta_performance_counter_1 on [dbo].[sqlwatch_meta_dm_os_performance_counters] ([date_updated])
go