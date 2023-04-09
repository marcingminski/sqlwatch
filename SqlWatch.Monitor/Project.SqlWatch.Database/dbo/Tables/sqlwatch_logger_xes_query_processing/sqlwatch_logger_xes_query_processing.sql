﻿CREATE TABLE [dbo].[sqlwatch_logger_xes_query_processing]
(
	[event_time] datetime not null,
	[max_workers] bigint,
	[workers_created] bigint,
	[idle_workers] bigint,
	[pending_tasks] bigint,
	[unresolvable_deadlocks] int,
	[deadlocked_scheduler] int,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null constraint df_sqlwatch_logger_xes_query_processing_type default (1) ,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_xes_query_processing_sql_instance default (@@SERVERNAME),
	constraint fk_logger_xe_query_processing_snapshot_header foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) on delete cascade  on update cascade,
	constraint fk_sqlwatch_logger_xes_query_processing_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
);
go