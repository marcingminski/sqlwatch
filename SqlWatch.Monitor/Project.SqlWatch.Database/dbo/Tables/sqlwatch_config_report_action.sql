CREATE TABLE [dbo].[sqlwatch_config_report_action]
(
	[report_id] smallint not null,
	[action_id] smallint not null,

	/*	primary key */
	constraint pk_sqlwatch_config_report_action primary key clustered ([report_id], [action_id]),

	/*	foreign key to action to make sure we reference only valid actions and to prevent deletion
		of actions when there is a reporting assosiated with it */
	constraint fk_sqlwatch_config_report_action_action foreign key ([action_id])
		references [dbo].[sqlwatch_config_action] ([action_id]) on delete no action,

	/*	foreign key to report to make sure we are only referencing valid report and to delete
		any assosiations when the report is deleted */
	constraint fk_sqlwatch_config_report_action_report foreign key ([report_id])
		references [dbo].[sqlwatch_config_report] ([report_id]) on delete cascade
)

GO

CREATE TRIGGER [dbo].[trg_sqlwatch_config_report_action_circular]
    ON [dbo].[sqlwatch_config_report_action]
    FOR INSERT, UPDATE
    AS
    BEGIN
	    set nocount on
		--prevent circular action to a report.
		--we could create an action that calls report which is configured to call the same action
		--this would result in a never ending loop.		
		if exists (select * 
			from inserted ra
				inner join [dbo].[sqlwatch_config_action] ca
				on ca.action_report_id = ra.report_id
				and ca.action_id = ra.action_id)
			begin
			  raiserror ('You cannot call an action that is calling this report as this would create circular reference.' ,16,1)
			  rollback transaction
			end
    END