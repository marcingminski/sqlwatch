CREATE TABLE [dbo].[sqlwatch_config_report_action]
(
	[sql_instance] varchar(32) not null default @@SERVERNAME,
	[report_id] smallint not null,
	[action_id] smallint not null,
	constraint pk_sqlwatch_config_report_action primary key clustered (
		[sql_instance], [report_id], [action_id]
	),
	constraint fk_sqlwatch_config_report_action_action foreign key ([action_id])
		references [dbo].[sqlwatch_config_action] ([action_id]),
	constraint fk_sqlwatch_config_report_action_report foreign key ([sql_instance], [report_id])
		references [dbo].[sqlwatch_config_report] ([sql_instance], [report_id]) on delete cascade
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