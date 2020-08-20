CREATE TABLE [dbo].[sqlwatch_meta_memory_clerk]
(
	[sql_instance] varchar(32) not null constraint df_sqlwatch_meta_memory_clerk_sql_instance default (@@SERVERNAME),
	[sqlwatch_mem_clerk_id] smallint identity(1,1),
	[clerk_name] nvarchar(255) not null,
	[date_updated] datetime not null constraint df_sqlwatch_meta_memory_clerk_updated default (getutcdate()),
	constraint pk_sqlwatch_meta_memory_clerk primary key clustered (
		[sql_instance], [sqlwatch_mem_clerk_id]
		),
	constraint uq_sqlwatch_meta_memory_clerk unique (
		[sql_instance], [clerk_name]
		),
	constraint fk_sqlwatch_meta_memory_clerk_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
go

create nonclustered index idx_sqlwatch_meta_memory_clerk_1 on [dbo].[sqlwatch_meta_memory_clerk] ([date_updated])
go

create trigger trg_sqlwatch_meta_memory_clerk_last_updated
	on [dbo].[sqlwatch_meta_memory_clerk]
	for insert,update
	as
	begin
		set nocount on;
		set xact_abort on;

		update t
			set date_updated = getutcdate()
		from [dbo].[sqlwatch_meta_memory_clerk] t
		inner join inserted i
			on i.[sql_instance] = t.[sql_instance]
			and i.[sqlwatch_mem_clerk_id] = t.[sqlwatch_mem_clerk_id]
			and i.[sql_instance] = @@SERVERNAME
	end
go