CREATE TABLE [dbo].[sqlwatch_meta_dm_os_wait_stats]
(
	[sql_instance] varchar(32) not null,
	[wait_type] nvarchar(60) not null, 
	[wait_type_id] int identity(1,1) not null,
	[is_excluded] bit,
	[date_updated] datetime not null constraint df_sqlwatch_meta_wait_stats_updated default (getutcdate()),
	constraint pk_sqlwatch_meta_wait_stats primary key (
		[sql_instance], [wait_type_id]
		),
	constraint uq_sqlwatch_meta_wait_stats_wait_type unique ([sql_instance],[wait_type]),
	constraint fk_sqlwatch_meta_wait_stats_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
go
 
create nonclustered index idx_sqlwatch_meta_wait_stats_1 
	on [dbo].[sqlwatch_meta_dm_os_wait_stats] ([date_updated])
go

create nonclustered index idx_sqlwatch_meta_wait_stats_2 
	on [dbo].[sqlwatch_meta_dm_os_wait_stats] ([is_excluded])
	include ([wait_type], [wait_type_id])
go