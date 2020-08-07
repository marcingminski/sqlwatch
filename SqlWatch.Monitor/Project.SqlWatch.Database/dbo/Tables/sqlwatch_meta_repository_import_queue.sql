CREATE TABLE [dbo].[sqlwatch_meta_repository_import_queue]
(
	[sql_instance] varchar(32) not null,
	[object_name] nvarchar(512) not null,
	[time_queued] datetime2(7) not null,
	[import_batch_id] uniqueidentifier not null,
	[parent_object_name] nvarchar(512) null,
	[priority] tinyint not null,
	[load_type] char(1) not null,
	[import_status] varchar(50),
	[import_start_time] datetime2(7),
	[import_end_time] datetime2(7),
	constraint pk_sqlwatch_repository_import_queue primary key clustered (
		[sql_instance], [object_name]
	)
)
