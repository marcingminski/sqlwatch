CREATE TABLE [dbo].[sqlwatch_meta_snapshot_header_baseline]
(
	[baseline_id] smallint not null,
	[snapshot_time] datetime2(0) not null,
	snapshot_type_id tinyint not null,
	[sql_instance] varchar(32) not null,

	constraint pk_sqlwatch_meta_snapshot_header_baseline 
		primary key clustered ([snapshot_time], [sql_instance], [snapshot_type_id], [baseline_id]),

	constraint fk_sqlwatch_meta_snapshot_header_baseline_meta
		foreign key ([baseline_id], [sql_instance])
		references dbo.sqlwatch_meta_baseline ([baseline_id], [sql_instance]) on delete cascade
);
go

