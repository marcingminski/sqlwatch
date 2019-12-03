CREATE TABLE [dbo].[sqlwatch_logger_snapshot_header]
(
	[snapshot_time] datetime2(0),
	[snapshot_type_id] tinyint not null,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_snapshot_header_sql_instance default (@@SERVERNAME),
	[report_time] AS (CONVERT([smalldatetime],dateadd(minute,ceiling(datediff(second,(0),CONVERT([time],CONVERT([datetime],[snapshot_time])))/(60.0)),datediff(day,(0),[snapshot_time])))) PERSISTED NOT NULL,
	
	/*	primary key */
	constraint pk_snapshot primary key clustered (
		[snapshot_time], [sql_instance], [snapshot_type_id]
	),

	/*	foreign key to snapshot type, to make sure we only have valid snapshots otherwise retention routines may not work */
	constraint fk_sqlwatch_logger_snapshot_header_type_id foreign key ([snapshot_type_id])
		references dbo.[sqlwatch_config_snapshot_type]([snapshot_type_id]),
	
	/*	foreign key on server to process delete cascades in central repository when removing server
		and to make sure we only have valid server. this will also simplify fks in child tables */
	constraint fk_snapshot_header_sql_instance foreign key (sql_instance) 
		references dbo.sqlwatch_config_sql_instance (sql_instance) on delete cascade on update cascade
)
go
create nonclustered index idx_sqlwatch_logger_snapshot_header_report_time 
	on [dbo].[sqlwatch_logger_snapshot_header] ([report_time])

go

create nonclustered index idx_sqlwatch_logger_snapshot_header_type_id
	on [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_type_id])
