﻿CREATE TABLE [dbo].[sqlwatch_logger_check]
(
	/* history of executed checks and results */
	[sql_instance] varchar(32) not null,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null constraint df_sqlwatch_logger_check_type default (18),
	[check_id] bigint not null,
	[check_value] real null,
	[check_status] varchar(15) not null, 
	[check_exec_time_ms] real null,
	[status_change] bit,
	[is_flapping] bit,
	[baseline_threshold] real, 

	/*	foreign key to header to process cascade retention */
	constraint fk_sqlwatch_logger_check_header foreign key ( [snapshot_time], [sql_instance], [snapshot_type_id] )
		references [dbo].[sqlwatch_logger_snapshot_header] ( [snapshot_time], [sql_instance], [snapshot_type_id] ) on delete cascade,

	/*	foreign key to config check to delete any logger records when the check is deleted */
	constraint fk_sqlwatch_meta_check foreign key ( [sql_instance], [check_id] )
		references dbo.[sqlwatch_meta_check] ( [sql_instance], [check_id] ) on delete cascade
)