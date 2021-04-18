create table [dbo].[sqlwatch_meta_performance_counter]
(
	[sql_instance] varchar(32) not null,
	[object_name] nvarchar(128) not null,
	[counter_name] nvarchar(128) not null,
	[cntr_type] int not null,
	[performance_counter_id] smallint identity(1,1),
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

create nonclustered index idx_sqlwatch_meta_performance_counter_1 on [dbo].[sqlwatch_meta_performance_counter] ([date_updated])
go

create trigger trg_sqlwatch_meta_performance_counter_last_updated
	on [dbo].[sqlwatch_meta_performance_counter]
	for insert,update
	as
	begin
		set nocount on;
		set xact_abort on;

		update t
			set date_updated = getutcdate()
		from [dbo].[sqlwatch_meta_performance_counter] t
		inner join inserted i
			on i.[sql_instance] = t.[sql_instance]
			and i.[performance_counter_id] = t.[performance_counter_id]
			and i.[sql_instance] = @@SERVERNAME
	end
go