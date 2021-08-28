CREATE TABLE [dbo].[sqlwatch_stage_app_log_last_read_event]
(
	event_sequence int,

	constraint pk_sqlwatch_stage_app_log_last_read_event 
		primary key clustered (event_sequence)
);
